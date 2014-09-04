#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use JSON;
use LWP;
use Net::GrowthForecast;

my $home = $ENV{"HOME"};
my $SecretConf = require("$home/ParseAnalyticUtils/conf/SecretConf.pm");
my $Conf = require("$home/ParseAnalyticUtils/conf/Conf.pm");
my $AppId = $SecretConf->{"AppId"};
my $RESTAPIKey = $SecretConf->{"RESTAPIKey"};
my @classes = @{$Conf->{logClasses}};

my $gf = Net::GrowthForecast->new( host => 'localhost', port => 5125 );

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime(time - 60);
my $compTime = sprintf("%04d-%02d-%02dT%02d:%02d", $year+1900, $mon + 1, $mday, $hour, $min);

# set interval to 10min
chop($compTime);
print "$compTime\n";

for (@classes) {
    print "$_\n";
    my $ua = LWP::UserAgent->new;
    my $res = $ua->get(
        "https://api.parse.com/1/classes/$_?limit=1000",
        "X-Parse-Application-Id" => $AppId,
        "X-Parse-REST-API-Key"   => $RESTAPIKey
    );

    if ($res->is_success) {
        my $res_json = $res->content;
        chomp($res_json);
        my $data = decode_json($res_json);

        my $count = 0;
        for my $res (keys %{$data}) {
            for (@{$data->{$res}}) {
                if ($_->{'createdAt'} =~ /^$compTime/) {
                    $count++;
                }
            }
        }
        $gf->post('Statistics', 'Log', $_, $count);
    }
}
