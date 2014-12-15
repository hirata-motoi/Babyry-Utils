package BabyryUtils::Service::GiveMePhoto;
use strict;
use warnings;
use utf8;

use YAML;
use SQL::Abstract;
use DateTime;
use DateTime::Format::Strptime;
use parent qw/BabyryUtils::Base/;

use BabyryUtils::Service::Child;

my $sqla = SQL::Abstract->new;
my $strp = DateTime::Format::Strptime->new(
    pattern   => '%Y-%m-%d %H:%M:%S',
    time_zone => 'UTC',
);


sub givemephoto_amount_by_family_id {
    my ($self, $dbname, $family_role, $opts) = @_;

    $opts ||= {};

    my %amount = ();

    my $dx = $self->dx('BABYRY_R', $dbname);

    my %user_ids = ();
    for my $family_id (keys %$family_role) {
        for my $part (qw/uploader chooser/) {
            die Dump $family_role->{$family_id} if !$family_role->{$family_id}{$part};
            $user_ids{ $family_role->{$family_id}{$part} } = $family_id;
        }
    }

    my @nh = $dx->select(
        'NotificationHistory',
        '*',
        { toUserId => {-in => [keys %user_ids]} , type => "requestPhoto"}
    )->hashes;

    my %count_by_user = ();
    for my $row (@nh) {
        my $family_id = $user_ids{$row->{touserid}};
        if ($opts->{$family_id} && $opts->{$family_id} < string2unixtime($row->{createdat})) {
            next;
        }
        $count_by_user{$row->{touserid}}++;
    }

    my %amount_by_family = ();
    for my $family_id (keys %$family_role) {
        for my $part (qw/uploader chooser/) {
            $amount_by_family{$family_id} += $count_by_user{$family_role->{$family_id}{$part}} || 0;
        }
    }

    return \%amount_by_family;
}

sub string2unixtime {
    my $string = shift;
    my $dt = $strp->parse_datetime($string);
    return $dt->epoch;
}

1;

