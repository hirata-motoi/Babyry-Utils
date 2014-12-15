package BabyryUtils::Service::Child;
use strict;
use warnings;
use utf8;

use YAML;
use SQL::Abstract;
use DateTime;
use DateTime::Format::Strptime;
use parent qw/BabyryUtils::Base/;

my $sqla = SQL::Abstract->new;
my $strp = DateTime::Format::Strptime->new(
    pattern   => '%Y-%m-%d %H:%M:%S',
    time_zone => 'UTC',
);

sub get_children_by_family_id {
    my ($self, $dbname, $family_id) = @_;

    my $dbh = $self->dbh('BABYRY_R', $dbname);
    my ($stmt, @bind) = $sqla->select('Child', [qw/*/], {familyId => $family_id});
    my $sth = $dbh->prepare($stmt);
    $sth->execute(@bind);
    my %children;
    while (my $row = $sth->fetchrow_hashref()) {
        $children{$row->{objectId}} = $row;
    }

    return \%children;
}

sub string2unixtime {
    my $string = shift;
    my $dt = $strp->parse_datetime($string);
    return $dt->epoch;
}


1;

