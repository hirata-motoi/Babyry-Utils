package BabyryUtils::Service::User;
use strict;
use warnings;
use utf8;

use YAML;
use SQL::Abstract;
use DateTime;
use DateTime::Format::Strptime;
use parent qw/BabyryUtils::Base/;

my $sqla = SQL::Abstract->new;

sub get_user_info {
    my ($self, $dbname, $user_id) = @_;

    my $dbh = $self->dbh('BABYRY_R', $dbname);

    my ($stmt, @bind) = $sqla->select('_User', [qw/*/], {userId => $user_id});
    my $sth = $dbh->prepare($stmt);
    $sth->execute(@bind);
    my $user = $sth->fetchrow_hashref();

    return $user;
}

sub get_users_by_family_id {
    my ($self, $dbname, $family_id) = @_;

    my $dbh = $self->dbh('BABYRY_R', $dbname);

    my ($stmt, @bind) = $sqla->select('_User', [qw/*/], {familyId => $family_id});
    my $sth = $dbh->prepare($stmt);
    $sth->execute(@bind);
    my $users;
    while(my $row = $sth->fetchrow_hashref()) {
        push @$users, $row;
    }

    return $users;
}

1;

