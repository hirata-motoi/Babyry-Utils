#!/usr/bin/env perl

use strict;
use warnings;

use LWP;
use Data::Dumper;
use JSON;

use BabyryUtils::Common;
use BabyryUtils::Service::User;
use BabyryUtils::Service::Child;

my $CONFIG = BabyryUtils::Common->config;
my $TOKEN = BabyryUtils::Common->get_key_vault('chatwork_token');
my $ROOM_ID = BabyryUtils::Common->get_key_vault('chatwork_bot_room_id');
my $BOT_ID = BabyryUtils::Common->get_key_vault('chatwork_bot_id');
my $END_POINT = $CONFIG->{chatwork_endpoint};

while(1) {
    my $ua = LWP::UserAgent->new;
    my $res = $ua->get(
        "$END_POINT/rooms/$ROOM_ID/messages",
        "X-ChatWorkToken" => $TOKEN
    );

    if ($res->is_success) {
        my $res_json = $res->content;
        chomp($res_json);
        if($res_json ne '') {
            my $data = decode_json($res_json);
            for my $post (@$data) {
                next if ($post->{account}->{account_id} eq $BOT_ID);
                my $message = &get_message($post->{body});
                if ($message) {
                    $ua->post(
                        "$END_POINT/rooms/$ROOM_ID/messages",
                        {
                            body => $message,
                        },
                        "X-ChatWorkToken" => $TOKEN
                    );
                }
            }
        }
    }
    sleep(1);
}

sub get_message {
    my $body = shift;

    if ($body =~ /whois\s*(u[a-zA-Z0-9]{5})(\s|$)/) {
        # get user nickName (emailは個人情報だから扱わない事にする)
        my $res = "";
        my $user = BabyryUtils::Service::User->new->get_user_info(&get_dbname(), $1);
        $res .= "FamilyId\t\t$user->{familyId}\n";
        $res .= "NickName\t$user->{nickName}\n";

        # get family
        my $users = BabyryUtils::Service::User->new->get_users_by_family_id(&get_dbname(), $user->{familyId});
        for (@$users) {
            if ($_->{userId} ne $user->{userId}) {
                $res .= "PartnerName\t$_->{nickName}\n";
            }
        }

        # get child
        my $children = BabyryUtils::Service::Child->new->get_children_by_family_id(&get_dbname(), $user->{familyId});
        my $child_nickname;
        for my $id (keys %$children) {
            $child_nickname .= $children->{$id}->{name} . "\t";
        }
        if ($child_nickname) {
            $res .= "ChildName\t$child_nickname\n";
        }

        return $res;
    }

    if ($body =~ /whois\s*(f[a-zA-Z0-9]{5})(\s|$)/) {
        my $res = "";
        my $family_id = $1;

        # get family
        my $users = BabyryUtils::Service::User->new->get_users_by_family_id(&get_dbname(), $family_id);
        for (@$users) {
            $res .= "UserInfo\t\t$_->{nickName}\t$_->{userId}\t$_->{sex}\n";
        }

        # get child
        my $children = BabyryUtils::Service::Child->new->get_children_by_family_id(&get_dbname(), $family_id);
        my $child_nickname;
        for my $id (keys %$children) {
            $child_nickname .= $children->{$id}->{name} . "\t";
        }
        if ($child_nickname) {
            $res .= "ChildName\t$child_nickname\n";
        }

        return $res;
    }

    print "no message send.\n";
    return;
}

sub get_dbname {
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
    #my $yyyymmdd = sprintf("%04d%02d%02d", $year + 1900, $mon + 1, $mday);
    my $yyyymmdd = "20141212";

    my $dbname = "babyry_$yyyymmdd";
    return $dbname;
}
