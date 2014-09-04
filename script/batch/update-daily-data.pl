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
my $today = sprintf("%04d-%02d-%02dT00:00:00.000Z", $year+1900, $mon + 1, $mday);
($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime(time - 60*60*24);
my $yesterday = sprintf("%04d-%02d-%02dT00:00:00.000Z", $year+1900, $mon + 1, $mday);

my @classes = @{$Conf->{imageClasses}};

my $createdAt_hash = {
    createdAt => {
        '$gte' => {
            '__type' => 'Date',
            'iso' => $yesterday,
        },
        '$lt' => {
            '__type' => 'Date',
            'iso' => $today,
        }
    }
};

my $createdAt_json = encode_json($createdAt_hash); 

my %params = (
    where => $createdAt_json,
    limit => 1000,
);

my $ua = LWP::UserAgent->new;

my $daily_total_image_num = 0;
my $daily_total_best_image_num = 0;

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
                $daily_total_image_num++;
                if ($_->{bestFlag} eq "choosed") {
                    $daily_total_best_image_num++;
                }
            }
        }
    }
}

$gf->post('Statistics', 'ImageDaily', "NumOfChildImage", $daily_total_image_num);
$gf->post('Statistics', 'ImageDaily', "NumOfChildBestShotImage", $daily_total_best_image_num);
