#!/usr/bin/env perl

use strict;
use warnings;

# this script don't access to parse
# make graph from backup data

use Data::Dumper;
use JSON;
use Net::GrowthForecast;

my $home = $ENV{"HOME"};
my $Conf = require("$home/ParseAnalyticUtils/conf/Conf.pm");
my @classes = @{$Conf->{classes}};
my $BACKUP_PARSE_DIR = "/data/backup/parse";

my $gf = Net::GrowthForecast->new( host => 'localhost', port => 5125 );

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
my $yyyymmddhh = sprintf("%04d%02d%02d%02d", $year + 1900, $mon + 1, $mday, $hour);
my $total_all_shard_image_num = 0;
my $total_all_shard_bestshot_image_num = 0;
my $total_all_shard_comment_num = 0;

{
    for (@classes) {
        if ($_ eq "_User") {
             &update_user();
        } elsif ($_ =~ /^(ChildImage\d)$/) {
            &update_image($1);
        } elsif ($_ =~ /^(Comment\d)$/) {
            &update_comment($1);
        } elsif ($_ eq "NotificationHistory") {
            &update_notificationhistory();
        }
    }
    $gf->post('Statistics', 'Image', 'NumOfChildImage', $total_all_shard_image_num);
    $gf->post('Statistics', 'Image', 'NumOfChildBestShotImage', $total_all_shard_bestshot_image_num);
    $gf->post('Statistics', 'Comment', 'NumOfComment', $total_all_shard_comment_num);

    my $complex_id;
    my $graphs = $gf->graphs();
    for my $g (@{$graphs}) {
        if (!defined($complex_id->{$g->{service_name}}->{$g->{section_name}})) {
            $complex_id->{$g->{service_name}}->{$g->{section_name}} = [];
        }
        push @{$complex_id->{$g->{service_name}}->{$g->{section_name}}}, $g->{id};
    }

    # remove all and add again
    for (@{$gf->complexes()}) {
        $gf->delete($gf->complex($_->{id}));
    }
    for my $service (keys $complex_id) {
        for my $section (keys $complex_id->{$service}) {
            $gf->add_complex($service, $section, 'ALL', "All Graph of $section", 0, 19, 'LINE2', 'gauge', 0, @{$complex_id->{$service}->{$section}});
        }
    }
}

sub update_user {
    my $total_user_num = 0;
    my $total_fam_num = 0;
    my $total_email_not_verified_num = 0;

    my $index = 0;
    my $inputfile = $BACKUP_PARSE_DIR . "/backup-parse-_User." . $yyyymmddhh . "-$index.json";

    while(-f $inputfile) {
        print "$inputfile\n";
        my $json = `head $inputfile\n`;
        chomp($json);
        my $data = decode_json($json);
        for my $res (keys %{$data}) {
            for my $user (@{$data->{$res}}) {
                $total_user_num++;
                if ($user->{familyId}) {
                    $total_fam_num++;
                }
                if ( defined($user->{emailVerified}) && $user->{emailVerified} == 0) {
                    $total_email_not_verified_num++;
                }
            }
        }
        $index++;
        $inputfile = $BACKUP_PARSE_DIR . "/backup-parse-_User." . $yyyymmddhh . "-$index.json";
    }

    # update growthforecast
    $gf->post('Statistics', 'User', 'TotalUser', $total_user_num);
    $gf->post('Statistics', 'User', 'HasFamilyId', $total_fam_num);
    $gf->post('Statistics', 'User', 'NotEmailVerified', $total_email_not_verified_num);
}

sub update_image {
    my $class = shift;

    my $index = 0;
    my $inputfile = $BACKUP_PARSE_DIR . "/backup-parse-$class." . $yyyymmddhh . "-$index.json";

    my $total_image_num = 0;   
    my $tmp_image_num = 0;

    while(-f $inputfile) {
        print "$inputfile\n";
        my $json = `head $inputfile\n`;
        chomp($json);
        my $data = decode_json($json);
        for my $res (keys %{$data}) {
            for my $image (@{$data->{$res}}) {
                $total_image_num++;

                if (defined($image->{isTmpData}) && $image->{isTmpData} eq "TRUE" ) {
                    $tmp_image_num++;
                }

                if ($image->{bestFlag} eq "choosed") {
                    $total_all_shard_bestshot_image_num++;
                }
            }
        }
        $index++;
        $inputfile = $BACKUP_PARSE_DIR . "/backup-parse-$class." . $yyyymmddhh . "-$index.json";
    }

    $total_all_shard_image_num += $total_image_num;

    # update growthforecast
    $gf->post('Statistics', 'Image', "NumOf$class", $total_image_num);
    $gf->post('Statistics', 'Image', "NumOfTmp$class", $tmp_image_num);
}

sub update_comment {
    my $class = shift;

    my $index = 0;
    my $inputfile = $BACKUP_PARSE_DIR . "/backup-parse-$class." . $yyyymmddhh . "-$index.json";

    my $total_comment_num = 0;

    while(-f $inputfile) {
        print "$inputfile\n";
        my $json = `head $inputfile\n`;
        chomp($json);
        my $data = decode_json($json);
        for my $res (keys %{$data}) {
            for my $image (@{$data->{$res}}) {
                $total_comment_num++;
            }
        }
        $index++;
        $inputfile = $BACKUP_PARSE_DIR . "/backup-parse-$class." . $yyyymmddhh . "-$index.json";
    }

    $total_all_shard_comment_num += $total_comment_num;

    # update growthforecast
    $gf->post('Statistics', 'Comment', "NumOf$class", $total_comment_num);
}

sub update_notificationhistory {
    my $ready_num = 0;
    my $displayed_num = 0;

    my %push_type;

    my $index = 0;
    my $inputfile = $BACKUP_PARSE_DIR . "/backup-parse-NotificationHistory." . $yyyymmddhh . "-$index.json";

    while (-f $inputfile) {
        print "$inputfile\n";
        my $json = `head $inputfile\n`;
        chomp($json);
        my $data = decode_json($json);
        for my $res (keys %{$data}) {
            for my $his (@{$data->{$res}}) {
                if ($his->{status} eq "ready") {
                    $ready_num++;
                } elsif ($his->{status} eq "displayed") {
                    $displayed_num++;
                }

                if ($his->{type}) {
                    $push_type{$his->{type}}++;
                }
            }
        }
        $index++;
        $inputfile = $BACKUP_PARSE_DIR . "/backup-parse-NotificationHistory." . $yyyymmddhh . "-$index.json";
    }

    # update growthforecast
    $gf->post('Statistics', 'NotificationHistory', 'Ready', $ready_num);
    $gf->post('Statistics', 'NotificationHistory', 'Displayed', $displayed_num);

    for (keys %push_type) {
        if ($push_type{$_}) {
            $gf->post('Statistics', 'NotificationHistory', "$_", $push_type{$_});
        }
    }
}

