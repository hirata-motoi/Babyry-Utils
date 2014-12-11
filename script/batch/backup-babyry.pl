#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use JSON;
use LWP;
use DBI;
use DateTime;
use Encode;

my $home = $ENV{"HOME"};
my $Conf = require("$home/Babyry-Utils/conf/Conf.pm");
my $SecretConf = require("$home/Babyry-Utils/conf/SecretConf.pm");
my $AppId = $SecretConf->{"AppId"};
my $RESTAPIKey = $SecretConf->{"RESTAPIKey"};

my $BACKUP_PARSE_DIR = "/data/backup/babyry";

my @classes = @{$Conf->{backupToMySQL}};

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);  
my $yyyymmdd = sprintf("%04d%02d%02d", $year + 1900, $mon + 1, $mday);

# create db
my $dbh = DBI->connect('dbi:mysql::mu002', $SecretConf->{'mysql'}->{'user'}, $SecretConf->{'mysql'}->{'password'}, {
});

my $res = $dbh->do("SHOW CREATE DATABASE babyry_$yyyymmdd");
if ($res) {
    die "Database already exist.";
}
$dbh->do("CREATE DATABASE babyry_$yyyymmdd");
$dbh->do("USE babyry_$yyyymmdd");

for my $class (@classes) {
    print "Backup $class\n";

    my $created_keys = {};

    my $index = 0;
    my $limit = 1000;
    while(1) {
        my $skip = $limit * $index;
        my $ua = LWP::UserAgent->new;
        my $res = $ua->get(
            "https://api.parse.com/1/classes/$class?limit=$limit&skip=$skip",
            "X-Parse-Application-Id" => $AppId,
            "X-Parse-REST-API-Key"   => $RESTAPIKey
        );

        if ($res->is_success) {
            my $res_json = $res->content;
            chomp($res_json);
            my $data = decode_json($res_json);

            my $res_num = 0;
            for my $res (keys %{$data}) {
                for my $record (@{$data->{$res}}) {
                    my $created_keys = &insert_record($class, $created_keys, $record);
                    $res_num++;
                }
            }
            last if ($res_num < $limit);
        } else {
            next;
        }
        $index++;
    }
}

sub insert_record {
    my $class = shift;
    my $created_keys = shift;
    my $record = shift;

    my $res = $dbh->do("SHOW CREATE TABLE $class");

    my $type_from_key = {};
    my $value_from_key = {};

    if (!$res) {
        # create "nickName varchar(32)"
        # from key is nickname, value is AAAAA
        my @ddl_keys;
        for my $key (keys %{$record}) {
            (my $type, my $value) = get_type_and_value($key, $record->{$key}, $class);
            $type_from_key->{$key} = $type;
            #$value =~ s/\"/\\"/g;
            $value =~ s/\n/ /g;
            $value_from_key->{$key} = $value;
           # print "$value\n";
            $created_keys->{$key} = 1;
            push @ddl_keys, "$key $type_from_key->{$key}";
        }
        my $ddl = "CREATE TABLE $class(" . join(',', @ddl_keys) . ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;';
        $dbh->do($ddl);
    } else {
        for my $key (keys %{$record}) {
            (my $type, my $value) = get_type_and_value($key, $record->{$key}, $class);
            $type_from_key->{$key} = $type;
            #$value =~ s/\"/\\"/g;
            $value =~ s/\n/ /g;
            $value_from_key->{$key} = $value;
            # print "$value\n";

            if (!$created_keys->{$key}) {
                (my $type, my $value) = get_type_and_value($key, $record->{$key}, $class);
                my $alter_ddl = "ALTER TABLE $class ADD $key $type;";
                $dbh->do($alter_ddl);
                $created_keys->{$key} = 1;
            }
        }
    }

    # insert value
    my $insert_query = 'INSERT INTO ' . $class . ' (' . join(',', keys %{$value_from_key}) . ") VALUES ('" . join("','", values %{$value_from_key}) . "');";
    $dbh->do($insert_query);

    return $created_keys;
}

sub get_type_and_value {
    my $key = shift;
    my $value = shift;
    my $class = shift;

    my $type = 'VARCHAR(255)';

    if ($value =~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)/) {
        $type = 'DATETIME';
        my $date = DateTime->new(
            time_zone => 'local',
            year => $1,
            month => $2,
            day => $3,
            hour => $4,
            minute => $5,
            second => $6
        );
        if ($key =~ /^createdAt|updatedAt$/) {
            $date->add(hours => 9);
            $value = $date->ymd('-') . ' ' . $date->hms(':');
        } else {
            $value = "$1-$2-$3 $4:$5:$6";
        }
    } elsif (ref($value) eq "HASH") {
        if ($value->{'__type'} eq 'Date') {
            if ($value->{'iso'} =~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)/) {
                $type = 'DATETIME';
                $value = "$1-$2-$3 $4:$5:$6";
            } else {
                die "cannot parse date";
            }
        } elsif ($value->{'__type'} eq 'Pointer') {
            $value = $value->{'objectId'};
        } elsif ($value->{'__type'} eq 'File') {
            my $trackingLogDir = '/data/backup/babyry/trackingLog';
            my $trackingLogName;
            if ($value->{'name'} =~ /([^-]+)-([^-]+)-(\d+)\.txt/) {
                $trackingLogName = $trackingLogDir . '/' . "$1-$2-$3.txt";
            } else {
                die "cannot parse log name";
            }
            my $trackingLogURL = $value->{'url'};
            if (-f $trackingLogName) {
                print "file already downloaded.\n";
            } else {
                print "download trackingLog $trackingLogName\n";
                system("wget $trackingLogURL -q -O $trackingLogName");
            }
        } else {
            die "unknown type";
        }
    } elsif ($value =~ /^\-*[0-9]+$/) {
        $type = 'BIGINT';
    } elsif ($class eq 'CritLog' && $key eq 'message') {
        $type = 'TEXT';
    }

    return ($type, $value);
}

1;
