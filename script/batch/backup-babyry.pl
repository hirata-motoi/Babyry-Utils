#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use JSON;
use LWP;
use DBI;
use DateTime;
use Encode;

use BabyryUtils::Common;

my $CONFIG          = BabyryUtils::Common->config;
my $HOME            = $ENV{"HOME"};
my $APPLICATION_ID  = BabyryUtils::Common->get_key_vault('parse_application_id');
my $CLIENT_KEY      = BabyryUtils::Common->get_key_vault('parse_client_key');
my $MYSQL_USER      = BabyryUtils::Common->get_key_vault('mysql_user');
my $MYSQL_PASS      = BabyryUtils::Common->get_key_vault('mysql_pass');

my $BACKUP_PARSE_DIR = "/data/backup/babyry";

my $CLASSES = $CONFIG->{backupToMySQL};

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);  
my $yyyymmdd = sprintf("%04d%02d%02d", $year + 1900, $mon + 1, $mday);

# create db
my $dbh = DBI->connect($CONFIG->{db_master}, $MYSQL_USER, $MYSQL_PASS, {
});

my $res = $dbh->do("SHOW CREATE DATABASE babyry_$yyyymmdd");
if ($res) {
    die "Database already exist.";
}
$dbh->do("CREATE DATABASE babyry_$yyyymmdd");
$dbh->do("USE babyry_$yyyymmdd");

for my $class (@$CLASSES) {
    print "Backup $class\n";

    my $created_keys = {};

    my $index = 0;
    my $limit = 1000;
    my $insert_record_list = [];
    while(1) {
        my $skip = $limit * $index;
        my $ua = LWP::UserAgent->new;
        my $res = $ua->get(
            "https://api.parse.com/1/classes/$class?limit=$limit&skip=$skip",
            "X-Parse-Application-Id" => $APPLICATION_ID,
            "X-Parse-REST-API-Key"   => $CLIENT_KEY
        );

        if ($res->is_success) {
            my $res_json = $res->content;
            chomp($res_json);
            my $data = decode_json($res_json);

            my $res_num = 0;
            for my $res (keys %{$data}) {
                for my $record (@{$data->{$res}}) {
                    my $created_keys = &prepare_record($class, $created_keys, $record, $insert_record_list);
                    $res_num++;
                }
            }
            last if ($res_num < $limit);
        } else {
            next;
        }
        $index++;
    }
    &insert_record($class, $insert_record_list);
}

sub insert_record {
    my $class = shift;
    my $insert_record_list = shift;

    my $max_num = 0;
    my @all_keys;
    for my $record (@$insert_record_list) {
        my $num = keys %$record;
        if ($num > $max_num) {
            $max_num = $num;
            @all_keys = keys %$record;
        }
    }

    my @query_values;
    for my $record (@$insert_record_list) {
        my @sorted_value = ();
        for my $key (@all_keys) {
            if (!$record->{$key}) {
                $record->{$key} = 'NULL';
            }
            push @sorted_value, $record->{$key};
        }
        my $query_value_string = '("' . join('","', @sorted_value) . '")';
        $query_value_string =~ s/\"NULL\"/NULL/g;
        push @query_values, $query_value_string;
    }
    my $insert_query = 'INSERT INTO ' . $class . ' (' . join(',', @all_keys) . ') VALUES ' . join(',', @query_values) . ';';
    $dbh->do($insert_query);
}

sub prepare_record {
    my $class = shift;
    my $created_keys = shift;
    my $record = shift;
    my $insert_record_list = shift;

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
            $value =~ s/\"/\\"/g;
            #$value =~ s/\n/ /g;
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

    push @$insert_record_list, $value_from_key;

    return $created_keys;
}

sub get_type_and_value {
    my $key = shift;
    my $value = shift;
    my $class = shift;

    my $type = 'VARCHAR(255)';

    if ($value =~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)\.(\d\d\d)Z$/) {
        $type = 'DATETIME(3)';
        my $msec = $7;
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
            $value = $date->ymd('-') . ' ' . $date->hms(':') . '.' . $msec;
        } else {
            $value = "$1-$2-$3 $4:$5:$6.$msec";
        }
    } elsif (ref($value) eq "HASH") {
        if ($value->{'__type'} eq 'Date') {
            if ($value->{'iso'} =~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)\.(\d\d\d)Z$/) {
                $type = 'DATETIME(3)';
                $value = "$1-$2-$3 $4:$5:$6.$7";
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
