package BabyryUtils::Service::ChildImage;
use strict;
use warnings;
use utf8;

use YAML;
use SQL::Abstract;
use DateTime;
use DateTime::Format::Strptime;
use parent qw/BabyryUtils::Base/;
use Data::Dumper;

use BabyryUtils::Service::Child;

my $sqla = SQL::Abstract->new;
#my $strp = DateTime::Format::Strptime->new(
#    pattern   => '%Y-%m-%d %H:%M:%S',
#    time_zone => 'JST',
#);

# コアユーザー度 : FamilyRoleのcreatedAtから今日までのBestShotうまり率
# BestShot総数 after(and equal) start date
# BestShot総数 before start date
# BestShot総数
# Upload総数 after(and equal) start date
# Upload総数 before start date
# Upload総数 ※ただし、removedはbackupに撮られないので無い
# 登録日のUpload枚数
# Upload総数の平均 after(and equal) start date (beforeはそもそもチョイスされないので意味が無い)

sub get_upload_image_statistics {
    my ($self, $dbname, $family_role) = @_;

    my $dbh = $self->dbh('BABYRY_R', $dbname);

    for my $family_id (keys %$family_role) {
        my $image_by_date = {};

        # こどもを取得
        my $children = BabyryUtils::Service::Child->new->get_children_by_family_id($dbname, $family_id);

        # 各こどもの写真を取得
        my %child_object_ids = ();
        for my $child_object_id (keys %$children) {
            my $s_index = $children->{$child_object_id}{childImageShardIndex};
            my $class = sprintf 'ChildImage%d', $s_index;
            $child_object_ids{$class} ||= [];
            push @{$child_object_ids{$class}}, $child_object_id;
        }
        for my $class (keys %child_object_ids) {
            my ($stmt, @bind) = $sqla->select(
                $class,
                ['*'],
                {
                    #bestFlag => "choosed",
                    imageOf => {-in => $child_object_ids{$class}},
                    #date => {'>=' => $self->unixtime2yyyymmdd($family_role->{$family_id}->{family_start_date})},
                }
            );
            my $sth = $dbh->prepare($stmt);
            $sth->execute(@bind);

            #my ($count) = $sth->fetchrow_array();
            #$amount += $count;
            while (my $row = $sth->fetchrow_hashref) {
                my $date = $row->{date};
                if ($row->{bestFlag} eq "choosed") {
                    # 子供が複数いても1にする
                    $image_by_date->{$date}->{choosed} = 1;
                } else {
                    $image_by_date->{$date}->{unchoosed}++;
                }
                $image_by_date->{$date}->{total}++;
            }
        }

        my $start_date = $self->unixtime2yyyymmdd($family_role->{$family_id}->{family_start_date});
        for my $date (keys %$image_by_date) {

            $family_role->{$family_id}->{upload_num} += $image_by_date->{$date}->{total};
            if ($image_by_date->{$date}->{choosed}) {
                $family_role->{$family_id}->{bestshot_num} += $image_by_date->{$date}->{choosed};
            }

            if ($date > $start_date) {
                $family_role->{$family_id}->{upload_num_after_start_date} += $image_by_date->{$date}->{total};
                if ($image_by_date->{$date}->{choosed}) {
                    $family_role->{$family_id}->{bestshot_num_after_start_date} += $image_by_date->{$date}->{choosed};
                }
            } elsif ($date < $start_date) {
                $family_role->{$family_id}->{upload_num_before_start_date} += $image_by_date->{$date}->{total};
                if ($image_by_date->{$date}->{choosed}) {
                    $family_role->{$family_id}->{bestshot_num_before_start_date} += $image_by_date->{$date}->{choosed};
                }
            } else {
                $family_role->{$family_id}->{upload_num_at_start_date} += $image_by_date->{$date}->{total};
                if ($image_by_date->{$date}->{choosed}) {
                    $family_role->{$family_id}->{bestshot_num_at_start_date} += $image_by_date->{$date}->{choosed};
                }
            }
        }

        # 継続日数で割る
        #my $elapsed_days = int($family_role->{$family_id}{elapsed_time} / (3600 * 24)) + 1;
        #$family_role->{$family_id}{activity_from_start_date} = sprintf '%.2f', $amount / $elapsed_days;
        #$family_role->{$family_id}{bestshot_num_from_start_date} = $amount;
    }
}

1;

