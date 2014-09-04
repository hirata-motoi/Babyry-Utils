#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use JSON;
use LWP;

my $home = $ENV{"HOME"};
my $Conf = require("$home/ParseAnalyticUtils/conf/Conf.pm");
my @classes = @{$Conf->{classes}};
my $BACKUP_PARSE_DIR = "/data/backup/parse";

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
my $yyyymmddhh = sprintf("%04d%02d%02d%02d", $year + 1900, $mon + 1, $mday, $hour);
my $ua = LWP::UserAgent->new;
my $total_all_shard_image_num = 0;
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
    $ua->post("http://localhost:5125/api/Statistics/Image/NumOfChildImage", { number => $total_all_shard_image_num});
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
    $ua->post("http://localhost:5125/api/Statistics/User/TotalUser", { number => $total_user_num});
    $ua->post("http://localhost:5125/api/Statistics/User/HasFamilyId", { number => $total_fam_num});
    $ua->post("http://localhost:5125/api/Statistics/User/NotEmailVerified", { number => $total_email_not_verified_num});
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
            }
        }
        $index++;
        $inputfile = $BACKUP_PARSE_DIR . "/backup-parse-$class." . $yyyymmddhh . "-$index.json";
    }

    $total_all_shard_image_num += $total_image_num;

    # update growthforecast
    $ua->post("http://localhost:5125/api/Statistics/Image/NumOf$class", {number => $total_image_num});
    $ua->post("http://localhost:5125/api/Statistics/Image/NumOfTmp$class", {number => $tmp_image_num});
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
    $ua->post("http://localhost:5125/api/Statistics/Comment/NumOf$class", {number => $total_comment_num++});
}

sub update_notificationhistory {
    my $ready_num = 0;
    my $displayed_num = 0;

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
            }
        }
        $index++;
        $inputfile = $BACKUP_PARSE_DIR . "/backup-parse-NotificationHistory." . $yyyymmddhh . "-$index.json";
    }

    # update growthforecast
    $ua->post("http://localhost:5125/api/Statistics/NotificationHistory/Ready", { number => $ready_num});
    $ua->post("http://localhost:5125/api/Statistics/NotificationHistory/Displayed", { number => $displayed_num});
}
