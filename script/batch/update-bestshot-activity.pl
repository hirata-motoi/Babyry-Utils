#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use JSON;
use Net::GrowthForecast;
use Time::Local;

my $home = $ENV{"HOME"};
my $Conf = require("$home/ParseAnalyticUtils/conf/Conf.pm");
my @classes = @{$Conf->{classes}};
my @imageClasses = @{$Conf->{imageClasses}};
my @staffFamilyId = @{$Conf->{staffFamilyId}};
my $BACKUP_PARSE_DIR = "/data/backup/parse";

my $gf = Net::GrowthForecast->new( host => 'localhost', port => 5125 );

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
my $yyyymmddhh = sprintf("%04d%02d%02d%02d", $year + 1900, $mon + 1, $mday, $hour);

my $activity_hashref = +{};
# FamilyId(Hash)
#  - childId
#     - date
#     - bestShotNum

{
    &set_familyId();
    &set_childId();
    &set_bestshot_num();
    &calc_activity();
    &make_graph();
}

sub set_familyId {
    my $index = 0;
    my $inputfile = $BACKUP_PARSE_DIR . "/backup-parse-_User." . $yyyymmddhh . "-$index.json";

    while(-f $inputfile) {
        print "$inputfile\n";
        my $json = `head $inputfile\n`;
        chomp($json);
        my $data = decode_json($json);
        for my $res (keys %{$data}) {
            for my $user (@{$data->{$res}}) {
                if ($user->{familyId}) {
                    $activity_hashref->{$user->{familyId}}->{userNum}++;
                }
            }
        }
        $index++;
        $inputfile = $BACKUP_PARSE_DIR . "/backup-parse-_User." . $yyyymmddhh . "-$index.json";
    }
}

sub set_childId {
    my $index = 0;
    my $inputfile = $BACKUP_PARSE_DIR . "/backup-parse-Child." . $yyyymmddhh . "-$index.json";

    while(-f $inputfile) {
        print "$inputfile\n";
        my $json = `head $inputfile\n`;
        chomp($json);
        my $data = decode_json($json);
        for my $res (keys %{$data}) {
            for my $child (@{$data->{$res}}) {
                $activity_hashref->{$child->{familyId}}->{childIds}->{$child->{objectId}} = +{};

                my $created_time;
                if ($child->{createdAt} =~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)\.\d\d\dZ$/) {
                    $created_time = timelocal($6, $5, $4, $3, $2 - 1, $1 - 1900) + 9 * 60 * 60;
                }

                $activity_hashref->{$child->{familyId}}->{childIds}->{$child->{objectId}}->{duration} = int((time - $created_time)/(24 * 60 * 60) + 1);
            }
        }
        $index++;
        $inputfile = $BACKUP_PARSE_DIR . "/backup-parse-Child." . $yyyymmddhh . "-$index.json";
    }
}

sub set_bestshot_num {
    my $bestshot_hashref = +{};
    for my $class (@imageClasses) {
        my $index = 0;
        my $inputfile = $BACKUP_PARSE_DIR . "/backup-parse-$class." . $yyyymmddhh . "-$index.json";

        while(-f $inputfile) {
            print "$inputfile\n";
            my $json = `head $inputfile\n`;
            chomp($json);
            my $data = decode_json($json);
            for my $res (keys %{$data}) {
                for my $image (@{$data->{$res}}) {
                    if ($image->{bestFlag} eq 'choosed') {
                        $bestshot_hashref->{$image->{imageOf}}++;
                    }
                }
            }
            $index++;
            $inputfile = $BACKUP_PARSE_DIR . "/backup-parse-$class." . $yyyymmddhh . "-$index.json";
        }
    }

    for my $familyId (keys %{$activity_hashref}) {
        for my $childId (keys %{$activity_hashref->{$familyId}->{childIds}}) {
            if ($bestshot_hashref->{$childId}) {
                $activity_hashref->{$familyId}->{childIds}->{$childId}->{bestshotNum} = $bestshot_hashref->{$childId};
            } else {
                $activity_hashref->{$familyId}->{childIds}->{$childId}->{bestshotNum} = 0;
            }
        }
    }
}

sub calc_activity {
    for my $familyId (keys %{$activity_hashref}) {
        my $max_ratio = 0;
        for my $childId (keys %{$activity_hashref->{$familyId}->{childIds}}) {
            my $ratio = int(100 * $activity_hashref->{$familyId}->{childIds}->{$childId}->{bestshotNum} / $activity_hashref->{$familyId}->{childIds}->{$childId}->{duration});
            $max_ratio = ($ratio > $max_ratio) ? $ratio : $max_ratio;
        }
        $activity_hashref->{$familyId}->{durationRatio} = $max_ratio;
    }
}

sub make_graph {
    my $ratio_map_hashref = +{};
    for my $familyId (keys %{$activity_hashref}) {
        unless (grep {$familyId eq $_} @staffFamilyId) {
            my $ratio = $activity_hashref->{$familyId}->{durationRatio};
            if ($ratio < 10) {
                $ratio_map_hashref->{'10'}++;
            } elsif ($ratio < 20) {
                $ratio_map_hashref->{'20'}++;
            } elsif ($ratio < 30) {
                $ratio_map_hashref->{'30'}++;
            } elsif ($ratio < 40) {
                $ratio_map_hashref->{'40'}++;
            } elsif ($ratio < 50) {
                $ratio_map_hashref->{'50'}++;
            } elsif ($ratio < 60) {
                $ratio_map_hashref->{'60'}++;
            } elsif ($ratio < 70) {
                $ratio_map_hashref->{'70'}++;
            } elsif ($ratio < 80) {
                $ratio_map_hashref->{'80'}++;
            } elsif ($ratio < 90) {
                $ratio_map_hashref->{'90'}++;
            } elsif ($ratio < 100) {
                $ratio_map_hashref->{'100'}++;
            } else {
                $ratio_map_hashref->{'over'}++;
            }
        }
    }

    for (0 .. 10) {
        my $lower = $_*10;
        my $upper = $lower + 10;
        if ($lower == 100) {
            if (defined $ratio_map_hashref->{over}) {
                $gf->post('Statistics', 'BestShotActivity', "over100%25", $ratio_map_hashref->{over});
            } else {
                $gf->post('Statistics', 'BestShotActivity', "over100%25", 0);
            }
        } else {
            if (defined $ratio_map_hashref->{"$upper"}) {
                $gf->post('Statistics', 'BestShotActivity', "${lower}%25-${upper}%25", $ratio_map_hashref->{"$upper"});
            } else {
                $gf->post('Statistics', 'BestShotActivity', "${lower}%25-${upper}%25", 0);
            }
        }
    }
}
