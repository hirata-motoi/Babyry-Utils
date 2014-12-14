package BabyryUtils::Service::Family;
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
#my $strp = DateTime::Format::Strptime->new(
#    pattern   => '%Y-%m-%d %H:%M:%S',
#    time_zone => 'UTC',
#);

sub paired_families {
    my ($self, $dbname) = @_;

    my $dbh = $self->dbh('BABYRY_R', $dbname);

    # FamilyRole
    my ($stmt, @bind) = $sqla->select('FamilyRole', [qw/*/]);
    my $sth = $dbh->prepare($stmt);
    $sth->execute(@bind);

    my @user_ids    = ();
    my %family_role = ();
    while (my $row = $sth->fetchrow_hashref()) {
        next unless $row->{uploader} && $row->{chooser};
        $family_role{$row->{familyId}} = $row;
        push @user_ids, $row->{uploader}, $row->{chooser};
    }

    # テストユーザ排除
    my %users = ();
    ($stmt, @bind) = $sqla->select('_User', [qw/*/], {userId => {-in => \@user_ids}});
    $sth = $dbh->prepare($stmt);
    $sth->execute(@bind);
    while (my $row = $sth->fetchrow_hashref()) {
        if (
            $row->{emailCommon} && $row->{emailCommon} =~ /(hirata\.motoi|mizutani2|rat\.tat\.tat|sands\.on\.earth|meaning\.co\.jp)/ ||
            $row->{nickName} && $row->{nickName} =~ /(no-signup|ミズタニ|けんじ|テスト|簡単|すなを)/
        ) {
            my $family_id = $row->{familyId};
            delete $family_role{$family_id};
        }
        $users{$row->{userId}} = $row;
    }

    # 最終写真アップ日と継続日時
    for my $family_id (keys %family_role) {
        my $uploader = $users{ $family_role{$family_id}{uploader} };
        my $chooser  = $users{ $family_role{$family_id}{chooser} };
        my $children = BabyryUtils::Service::Child->new->get_children_by_family_id($dbname, $family_id);

        # 最新アップロード画像のcreatedAt
        my $latest_upload_date = $self->get_latest_upload_date($dbname, $children);
        $family_role{$family_id}{latest_upload_date} = $latest_upload_date;

        # family_roleのcreatedAt(familyといいつつ最初に始めた方のfamilyRoleが作られるタイミング)
        my $family_start_date = $self->string2unixtime($family_role{$family_id}{createdAt});
        $family_role{$family_id}{family_start_date} = $family_start_date;

        # 始めた日から最後に画像を上げた日(アクティブな期間)
        my $active_time = $latest_upload_date ? $latest_upload_date - $family_start_date : 0;
        $family_role{$family_id}{active_time} = $active_time;

        # 始めた日から今日までの期間(経過日数)
        my $elapsed_time = time() - $family_start_date;
        $family_role{$family_id}{elapsed_time} = $elapsed_time;
    }

    return \%family_role, \%users;
}

sub get_latest_upload_date {
    my ($self, $dbname, $children) = @_;

    my %child_object_ids = ();
    for my $child_object_id (keys %$children) {
        my $s_index = $children->{$child_object_id}{childImageShardIndex};
        my $class = sprintf 'ChildImage%d', $s_index;
        $child_object_ids{$class} ||= [];
        push @{$child_object_ids{$class}}, $child_object_id;
    }

    my @unixtimes = ();
    my $dbh = $self->dbh('BABYRY_R', $dbname);
    for my $class (keys %child_object_ids) {
        my ($stmt, @bind) = $sqla->select($class, ['unix_timestamp(createdAt) AS c'], {imageOf => $child_object_ids{$class}});
        my $sth = $dbh->prepare($stmt);
        $sth->execute(@bind);
        while (my $row = $sth->fetchrow_hashref()) {
            push @unixtimes, $row->{c};
        }
    }

    return if !@unixtimes;
    my $latest = (sort {$b <=> $a} @unixtimes)[0];
    return $latest;
}

#sub string2unixtime {
#    my $string = shift;
#    my $dt = $strp->parse_datetime($string);
#    return $dt->epoch;
#}


1;

