package BabyryUtils::Service::BestShot;
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

sub bestshot_amount {
    my ($self, $dbname, $family_ids, $opts) = @_;

    $opts ||= {};

    my %amount = ();

    my $dbh = $self->dbh('BABYRY_R', $dbname);
    for my $family_id (@$family_ids) {
        my $children = BabyryUtils::Service::Child->new->get_children_by_family_id($dbname, $family_id);
        my %conf = ();
        for my $child_object_id (keys %$children) {
            my $s_index = $children->{$child_object_id}{childImageShardIndex};
            my $db = sprintf 'ChildImage%d', $s_index;
            $conf{$db} ||= [];
            push @{$conf{$db}}, $child_object_id;
        }

        my $option = $opts->{$family_id}
            ? { 'unix_timestamp(createdAt)' => {'<=' => $opts->{$family_id}} }
            : {};
        for my $db (keys %conf) {
            my ($stmt, @bind) = $sqla->select(
                $db,
                ['COUNT(*)'],
                {
                    imageOf => {-in => $conf{$db}},
                    bestFlag => 'choosed',
                    %$option
                }
            );
            my $sth = $dbh->prepare($stmt);
            $sth->execute(@bind);

            my ($count) = $sth->fetchrow_array();
            $amount{$family_id} += $count;
        }
    }
    return \%amount;
}

sub bestshot_amount_from_start {
    my ($self, $dbname, $family_ids, $opts) = @_;

    $opts ||= {};

    my %amount = ();

    my $dbh = $self->dbh('BABYRY_R', $dbname);
    for my $family_id (@$family_ids) {
        my $children = BabyryUtils::Service::Child->new->get_children_by_family_id($dbname, $family_id);
        my %conf = ();
        for my $child_object_id (keys %$children) {
            my $s_index = $children->{$child_object_id}{childImageShardIndex};
            my $db = sprintf 'ChildImage%d', $s_index;
            $conf{$db} ||= [];
            push @{$conf{$db}}, $child_object_id;
        }

        my $option = $opts->{$family_id}
            ? { 'unix_timestamp(createdAt)' => {'>=' => $opts->{$family_id}} }
            : {};
        for my $db (keys %conf) {
            my ($stmt, @bind) = $sqla->select(
                $db,
                ['COUNT(*)'],
                {
                    imageOf => {-in => $conf{$db}},
                    bestFlag => 'choosed',
                    %$option
                }
            );
            my $sth = $dbh->prepare($stmt);
            $sth->execute(@bind);

            my ($count) = $sth->fetchrow_array();
            $amount{$family_id} += $count;
        }
    }
    return \%amount;
}

sub bestshot_timezone_average {
    my ($self, $dbname, $family_role) = @_;

    my %average = ();

    my $dx = $self->dx('BABYRY_R', $dbname);
    for my $family_id (keys %$family_role) {
        my @user_ids = @{$family_role->{$family_id}}{qw/uploader chooser/};
        my @nhs = $dx->select(
            'NotificationHistory',
            '*',
            {
                toUserId => {
                    -in => \@user_ids
                }
            }
        )->hashes;

        next if !@nhs;

        my @hours = ();
        for my $row (@nhs) {
            my $createdat = $row->{createdat};
            my $dt = $strp->parse_datetime($createdat);
            push @hours, $dt->hour;
        }

        my $sum;
        map { $sum += $_ } @hours;
        $average{$family_id} = int( $sum / scalar(@hours) );
    }
    return \%average;
}

sub string2unixtime {
    my $string = shift;
    my $dt = $strp->parse_datetime($string);
    return $dt->epoch;
}

1;

