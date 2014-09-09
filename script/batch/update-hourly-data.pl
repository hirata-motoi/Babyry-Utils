#!/usr/bin/env perl

use strict;
use warnings;

# this script get data from Parse via API
# not from backup data

use Data::Dumper;
use JSON;
use LWP;
use URI;
use URI::Escape;
use Net::GrowthForecast;

my $home = $ENV{"HOME"};
my $SecretConf = require("$home/ParseAnalyticUtils/conf/SecretConf.pm");
my $Conf = require("$home/ParseAnalyticUtils/conf/Conf.pm");
my $AppId = $SecretConf->{"AppId"};
my $RESTAPIKey = $SecretConf->{"RESTAPIKey"};

my $gf = Net::GrowthForecast->new( host => 'localhost', port => 5125 );

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime(time);
my $now = sprintf("%04d-%02d-%02dT%02d:00:00.000Z", $year+1900, $mon + 1, $mday, $hour);
($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime(time - 60*60);
my $hour_ago = sprintf("%04d-%02d-%02dT%02d:00:00.000Z", $year+1900, $mon + 1, $mday, $hour);

my $yyyymmdd = sprintf("%04d%02d%02d", $year+1900, $mon + 1, $mday);

my @classes = @{$Conf->{imageClasses}};

my $createdAt_hash = {
    createdAt => {
        '$gte' => {
            '__type' => 'Date',
            'iso' => $hour_ago,
        },
        '$lt' => {
            '__type' => 'Date',
            'iso' => $now,
        }
    }
};

my $createdAt_json = encode_json($createdAt_hash); 

my %params = (
    where => $createdAt_json,
    limit => 1000,
);

my $ua = LWP::UserAgent->new;

my $hourly_total_image_num = 0;
my $hourly_total_image_num_today = 0;
my $hourly_total_best_image_num = 0;
my $hourly_total_best_image_num_today = 0;

for (@classes) {
    my $url = URI->new("https://api.parse.com/1/classes/$_");
    $url->query_form(%params);

    my $res = $ua->get(
        $url,
        "X-Parse-Application-Id" => $AppId,
        "X-Parse-REST-API-Key"   => $RESTAPIKey
    );

    if ($res->is_success) {
        my $res_json = $res->content;
        chomp($res_json);
        my $data = decode_json($res_json);

        for my $res (keys %{$data}) {
            for (@{$data->{$res}}) {
                $hourly_total_image_num++;
                if ($_->{date} eq $yyyymmdd) {
                    $hourly_total_image_num_today++;
                }
                if ($_->{bestFlag} eq "choosed") {
                    $hourly_total_best_image_num++;
                    if ($_->{date} eq $yyyymmdd) {
                        $hourly_total_best_image_num_today++;
                    }
                }
            }
        }
    }
}

$gf->post('Statistics', 'ImageHourly', "NumOfChildImage", $hourly_total_image_num);
$gf->post('Statistics', 'ImageHourly', "NumOfChildBestShotImage", $hourly_total_best_image_num);
$gf->post('Statistics', 'ImageHourly', "NumOfChildImageToday", $hourly_total_image_num_today);
$gf->post('Statistics', 'ImageHourly', "NumOfChildBestShotImageToday", $hourly_total_best_image_num_today);
