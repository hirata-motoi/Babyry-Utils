package BabyryUtils::Base;
use strict;
use warnings;
use utf8;

use parent qw/Class::Accessor::Fast/;

use BabyryUtils::DBI;
use DBIx::Simple;
use Teng::Schema::Loader;
use SQL::Abstract;
use SQL::Abstract::Plugin::InsertMulti;
use Data::Dump;
use Class::Load qw/load_class/;
use String::CamelCase qw/camelize/;
use SQL::Maker;
use DateTime;
use DateTime::Format::Strptime;
use Data::Dumper;

my $strp = DateTime::Format::Strptime->new(
    pattern   => '%Y-%m-%d %H:%M:%S',
    time_zone => 'Asia/Tokyo',
);

SQL::Maker->load_plugin('InsertMulti');

sub dbh {
    my ($self, $label, $db_name) = @_;

    my $resolver = BabyryUtils::DBI->resolver($db_name);
    my $dbh = $resolver->connect($label);
    $dbh;
}

sub dx {
    my ($self, $label, $db_name, $dbh) = @_;

    $dbh ||= $self->dbh($label, $db_name);
    my $dx = DBIx::Simple->new($dbh);
    return $dx;
}

sub teng {
    my ($self, $label) = @_;

    $self->{teng} ||= {};
    return $self->{teng}{$label} if $self->{teng}{$label};

    my $teng = Teng::Schema::Loader->load(
        namespace => 'BabyryUtils::Teng',
        dbh       => $self->dbh($label),
    );
    $teng->load_plugin('Count');
    $teng->load_plugin('Lookup');
    $self->{teng}{$label} = $teng;
    return $self->{teng}{$label};
}

sub dump {
    my ($self, $params) = @_;
    return Data::Dump::dump($params);
}

sub string2unixtime {
    my ($self, $string) = @_;
    my $dt = $strp->parse_datetime($string);
    return $dt->epoch;
}

sub unixtime2yyyymmdd {
    my ($self, $unixtime) = @_;
    my $dt = DateTime->from_epoch(time_zone => 'Asia/Tokyo', epoch => $unixtime);
    my $yyyymmdd = sprintf("%04d", $dt->year) . sprintf("%02d", $dt->month) . sprintf("%02d", $dt->day);
    return $yyyymmdd;
}


1;

