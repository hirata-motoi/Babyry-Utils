package BabyryUtils::Service::Comment;
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


sub comment_amount_by_family_id {
    my ($self, $dbname, $family_ids, $opts) = @_;

    $opts ||= {};

    my %amount = ();

    my $dbh = $self->dbh('BABYRY_R', $dbname);
    for my $family_id (@$family_ids) {
        my $children = BabyryUtils::Service::Child->new->get_children_by_family_id($dbname, $family_id);
        my %conf = ();
        for my $child_object_id (keys %$children) {
            my $c_index = $children->{$child_object_id}{commentShardIndex};
            my $db = sprintf 'Comment%d', $c_index;
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
                    childId => {-in => $conf{$db}},
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

1;

