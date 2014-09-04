#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use JSON;
use LWP;

my $home = $ENV{"HOME"};
my $Conf = require("$home/ParseAnalyticUtils/conf/Conf.pm");
my $SecretConf = require("$home/ParseAnalyticUtils/conf/SecretConf.pm");
my $AppId = $SecretConf->{"AppId"};
my $RESTAPIKey = $SecretConf->{"RESTAPIKey"};

my $BACKUP_PARSE_DIR = "/data/backup/parse/tmp";

my @classes = @{$Conf->{classes}};

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);  
my $yyyymmddhh = sprintf("%04d%02d%02d%02d", $year + 1900, $mon + 1, $mday, $hour);

for (@classes) {
    print "Backup $_\n";

    my $index = 0;
    my $limit = 100;
    while(1) {
        my $skip = $limit * $index;
        my $ua = LWP::UserAgent->new;
        my $res = $ua->get(
            "https://api.parse.com/1/classes/$_?limit=$limit&skip=$skip",
            "X-Parse-Application-Id" => $AppId,
            "X-Parse-REST-API-Key"   => $RESTAPIKey
        );

        if ($res->is_success) {
            my $outputfile = $BACKUP_PARSE_DIR . "/backup-parse-$_." . $yyyymmddhh . "-${index}.json";
            open(OUT, ">$outputfile");
            print OUT $res->content;

            my $res_json = $res->content;
            chomp($res_json);
            my $data = decode_json($res_json);

            my $res_num = 0;
            for my $res (keys %{$data}) {
                for (@{$data->{$res}}) {
                    $res_num++;
                }
            }
            print "$res_num\n";
            last if ($res_num < 100);
        } else {
            next;
        }

        $index++;
    }
}


