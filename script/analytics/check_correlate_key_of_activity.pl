#!/usr/bin/env perl

# コアユーザー度と相関のある指標のグラフ化
# コアユーザー度は登録日から今日までのパネルに写真埋まっている率
# 相関を調べる指標
# 1. BS総数
# 2. 写真アップ総数
# 3. 一日あたりの平均アップ数

use strict;
use warnings;
use BabyryUtils::Common;
use BabyryUtils::Service::Family;
use BabyryUtils::Service::BestShot;
use BabyryUtils::Service::ChildImage;
use YAML;
use JSON::XS;
use List::Util qw/max min/;
use Data::Dumper;

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
#my $yyyymmdd = sprintf("%04d%02d%02d", $year + 1900, $mon + 1, $mday);
my $yyyymmdd = "20141212";

my $dbname = "babyry_$yyyymmdd";

# ペアになっている人だけが対象
my ($family_role, $users) = BabyryUtils::Service::Family->new->paired_families($dbname);

# 画像関連数値取得
BabyryUtils::Service::ChildImage->new->get_upload_image_statistics($dbname, $family_role);

# コアユーザー度
my @y = ();
for my $family_id (keys %$family_role) {
    # コアユーザー度
    $family_role->{$family_id}->{bestshot_num_at_start_date} ||= 0;
    $family_role->{$family_id}->{bestshot_num_after_start_date} ||= 0;
    my $bestshot_num_after_and_at_start_date = $family_role->{$family_id}->{bestshot_num_at_start_date} + $family_role->{$family_id}->{bestshot_num_after_start_date};
    push @y, 100 * $bestshot_num_after_and_at_start_date / ($family_role->{$family_id}->{elapsed_time} / 60 / 60 / 24);
}

# vs BestShot総数
{
    my @x = ();
    for my $family_id (keys %$family_role) {
        $family_role->{$family_id}->{bestshot_num} ||= 0;
        push @x, $family_role->{$family_id}->{bestshot_num};
    }
    output(\@x, \@y, 'bestshot num', 'bestshot ratio', 'bestshot_ratio_vs_bestshot_num');
}

# vs BestShot数 after start
{
    my @x = ();
    for my $family_id (keys %$family_role) {
        $family_role->{$family_id}->{bestshot_num_after_start_date} ||= 0;
        $family_role->{$family_id}->{bestshot_num_at_start_date} ||= 0;
        push @x, $family_role->{$family_id}->{bestshot_num_after_start_date} + $family_role->{$family_id}->{bestshot_num_at_start_date};
    }
    output(\@x, \@y, 'bestshot num after start', 'bestshot ratio', 'bestshot_ratio_vs_bestshot_num_after_start');
}

# vs BestShot数 before start
{
    my @x = ();
    for my $family_id (keys %$family_role) {
        $family_role->{$family_id}->{bestshot_num_before_start_date} ||= 0;
        push @x, $family_role->{$family_id}->{bestshot_num_before_start_date};
    }
    output(\@x, \@y, 'bestshot num before start', 'bestshot ratio', 'bestshot_ratio_vs_bestshot_num_before_start');
}

# vs Upload総数
{
    my @x = ();
    for my $family_id (keys %$family_role) {
        $family_role->{$family_id}->{upload_num} ||= 0;
        push @x, $family_role->{$family_id}->{upload_num};
    }
    output(\@x, \@y, 'upload num', 'bestshot ratio', 'bestshot_ratio_vs_upload_num');
}

# vs Upload数 after start
{
    my @x = ();
    for my $family_id (keys %$family_role) {
        $family_role->{$family_id}->{upload_num_after_start_date} ||= 0;
        $family_role->{$family_id}->{upload_num_at_start_date} ||= 0;
        push @x, $family_role->{$family_id}->{upload_num_after_start_date} + $family_role->{$family_id}->{upload_num_at_start_date};
    }
    output(\@x, \@y, 'upload num after start', 'bestshot ratio', 'bestshot_ratio_vs_upload_num_after_start');
}

# vs Upload数 before start
{
    my @x = ();
    for my $family_id (keys %$family_role) {
        $family_role->{$family_id}->{upload_num_before_start_date} ||= 0;
        push @x, $family_role->{$family_id}->{upload_num_before_start_date};
    }
    output(\@x, \@y, 'upload num before start', 'bestshot ratio', 'bestshot_ratio_vs_upload_num_before_start');
}

# vs Upload数 at start
{
    my @x = ();
    for my $family_id (keys %$family_role) {
        $family_role->{$family_id}->{upload_num_at_start_date} ||= 0;
        push @x, $family_role->{$family_id}->{upload_num_at_start_date};
    }
    output(\@x, \@y, 'upload num at start', 'bestshot ratio', 'bestshot_ratio_vs_upload_num_at_start');
}

sub output {
    my ($x, $y, $xlabel, $ylabel, $filename) = @_;

    my @d;
    my $i = 0;
    for my $x (@$x) {
        my @unit = ($x, $y->[$i]);
        push @d, \@unit;
        $i++;
    }
    my $data_text = encode_json(\@d);
    my $xticks = encode_json([ min(@$x) , max(@$x) ]);
    my $yticks = encode_json([ min(@$y) , max(@$y) ]);

    my $text = <<"TEXT";
<script>
        var d   = $data_text,
        xlabel = "$xlabel",
        ylabel = "$ylabel",
        xticks = $xticks,
        yticks = $yticks;
</script>
TEXT
    my @rows = ();
    my $tmpl_path = 'tmpl/scatter_template.html';
    open my $fh, "< $tmpl_path" or die;
    open my $fh2, "> tmpl/scatterDiagram/$filename.html" or die;
    while (<$fh>) {
        if ($_ =~ /DATA_CONTAINER/) {
            print $fh2 $text."\n";
        } else {
            print $fh2 $_;
        }
    }
    close $fh;
}
