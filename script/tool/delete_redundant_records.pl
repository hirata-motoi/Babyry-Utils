#!/usr/bin/env perl

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request;
use JSON::XS;
use Getopt::Long;
use Term::UI;
use Term::ReadLine;
use YAML;
use DateTime;
use File::Path qw/mkpath/;

use BabyryUtils::Common;

my $UA          = LWP::UserAgent->new;
my $URI_BASE    = 'https://api.parse.com/1/classes/%s';
my $URI_DISABLE = 'https://api.parse.com/1/functions/user_delete';
my $LOG_DIR     = 'log';
my $LOG_FILE_BASE = 'delete_redundant_record.log.%d';

my $APPLICATION_ID = BabyryUtils::Common->get_key_vault('parse_application_id');
my $CLIENT_KEY     = BabyryUtils::Common->get_key_vault('parse_client_key');
my @family_ids;

GetOptions('family_id|f=s' => \@family_ids);

main();

sub main {
    my @users = get_from_user(@family_ids);

    my %children       = get_from_child(@family_ids);
    my %comments       = get_from_comment(%children);
    my %child_images   = get_from_child_image(%children);
    my %family_roles   = get_from_family_role(@family_ids);
    my %tutorial_maps  = get_from_tutorial_map(@users);

    my $output = create_output_text({
        users         => \@users,
        children      => \%children,
        family_ids    => \@family_ids,
        comments      => \%comments,
        child_images  => \%child_images,
        family_roles  => \%family_roles,
        tutorial_maps => \%tutorial_maps,
    });

    my $term = Term::ReadLine->new('Delete Users');
    my $bool = $term->ask_yn(
        print_me => $output,
        prompt   => 'Really delete these users and children?',
        default  => 'n'
    );

    if (!$bool) {
        return;
    }

    delete_objects(
        users         => \@users,
        children      => \%children,
        family_ids    => \@family_ids,
        comments      => \%comments,
        child_images  => \%child_images,
        family_roles  => \%family_roles,
        tutorial_maps => \%tutorial_maps,
    );
}

sub get_from_user {
    my (@user_ids) = @_;

    my $users = get('_User', { familyId => { '$in' => \@family_ids } });

    return @$users;
}

sub get_from_child {
    my (@family_ids) = @_;

    my $results = get('Child', { familyId => {'$in' => \@family_ids } });

    my %children = ();
    for my $child (@$results) {
        my $family_id = $child->{familyId};
        $children{$family_id} ||= [];
        push @{ $children{$family_id} }, $child;
    }

    return %children;
}

sub get_from_comment {
    my %children = @_;

    my %child_ids_by_shard_index;

    for my $children_by_family (values %children) {
        for my $child (@$children_by_family) {
            my $shard_index = $child->{commentShardIndex};
            $child_ids_by_shard_index{$shard_index} ||= [];
            push @{ $child_ids_by_shard_index{$shard_index} }, $child->{objectId};
        }
    }

    my %comments = ();
    for my $shard_index (keys %child_ids_by_shard_index) {
        my $class_name = sprintf 'Comment%d', $shard_index;
        my $comments   = get($class_name, {
            childId => {'$in' => $child_ids_by_shard_index{$shard_index}}
        });

        for my $comment (@$comments) {
            $comments{$comment->{childId}} ||= [];
            push @{ $comments{$comment->{childId}} }, $comment;
        }
    }
    return %comments;
}

sub get_from_child_image {
    my %children = @_;

    my %child_ids_by_shard_index;

    for my $children_by_family (values %children) {
        for my $child (@$children_by_family) {
            my $shard_index = $child->{childImageShardIndex};
            $child_ids_by_shard_index{$shard_index} ||= [];
            push @{ $child_ids_by_shard_index{$shard_index} }, $child->{objectId};
        }
    }

    my %child_images = ();
    for my $shard_index (keys %child_ids_by_shard_index) {
        my $class_name = sprintf 'ChildImage%d', $shard_index;
        my $child_images   = get($class_name, {
            imageOf => {'$in' => $child_ids_by_shard_index{$shard_index}}
        });

        for my $child_image (@$child_images) {
            $child_images{$child_image->{imageOf}} ||= [];
            push @{ $child_images{$child_image->{imageOf}} }, $child_image;
        }
    }
    return %child_images;
}

sub get_from_family_role {
    my (@family_ids) = @_;

    my $results = get('FamilyRole', { familyId => {'$in' => \@family_ids} }) || [];

    my %family_roles = map { $_->{familyId} => $_ } @$results;

    return %family_roles;
}

sub get_from_tutorial_map {
    my (@users) = @_;

    my $results = get('TutorialMap', { userId => {'$in' => [map { $_->{userId} } @users] } } ) || [];

    my %tutorial_maps = map { $_->{userId} => $_ } @$results;

    return %tutorial_maps;
}

sub create_output_text {
    my $params = shift;

    my @source;

    for my $family_id (@{$params->{family_ids}}) {
        my %unit;

        $unit{familyId} = $family_id;

        my @target_users = grep { $_->{familyId} eq $family_id } @{$params->{users}};

        for my $user (@target_users) {
            $unit{User} ||= [];

            my $user_unit = {
                info => join("\t", @$user{qw/userId nickName emailCommon/}),
            };
            if (my $tutorial_map = $params->{tutorial_maps}{$user->{userId}}) {
                $user_unit->{TutorialMap} = join("\t", @$tutorial_map{qw/objectId/});
            }
            push @{$unit{User}}, $user_unit;
        }

        if (my $target_children = $params->{children}{$family_id}) {
            for my $child (@$target_children) {
                $unit{Child}   ||= [];

                my $child_images = $params->{child_images}{$child->{objectId}} || [];
                my $comments     = $params->{comments}{$child->{objectId}}     || [];

                my $child_unit = {
                    info       => join("\t", @$child{qw/objectId name/}),
                    ChildImage => [map {
                        join("\t", @$_{qw/objectId bestFlag date imageOf/})
                    } @$child_images],
                    Comment => [map {
                        join("\t", @$_{qw/objectId childId comment commentBy date/})
                    } @$comments],
                };

                push @{$unit{Child}}, $child_unit;
            }
        }

        if (my $family_role = $params->{family_roles}{$family_id}) {
            my @elems = (@$family_role{qw/objectId familyId/}, '(U)'.$family_role->{uploader}, '(C)'.$family_role->{chooser});
            $unit{FamilyRole} = join("\t", @elems);
        }

        push @source, \%unit;
    }
    return if !@source;

    return format_lines(@source);
}

sub get {
    my ($class_name, $params) = @_;

    my $uri = sprintf $URI_BASE, $class_name;
    $uri    .= sprintf '?where=%s', encode_json($params);

    print $uri, "\n";

    my $req = HTTP::Request->new("GET", $uri);
    $req->header("X-Parse-Application-Id" => $APPLICATION_ID, "X-Parse-REST-API-Key" => $CLIENT_KEY);
    my $res = $UA->request($req);

    if ($res->is_success) {
        my @result = ();
        my $decoded_json = decode_json( $res->decoded_content );
        return $decoded_json->{results};
    } else {
        die $res->message;
    }
}

sub format_lines {
    my @source = @_;

    my @lines = ();

    for my $unit (@source) {
        push @lines, "-------------------------";
        push @lines, 'FamilyId:'. "\t" .  $unit->{familyId};
        push @lines, 'FamilyRole:' . "\t" . $unit->{FamilyRole};

        push @lines, 'User:';
        for my $user (@{$unit->{User}}) {
            push @lines, "\t" . $user->{info} . "\t" . sprintf('(TutorialMap:%s)', $user->{TutorialMap});
        }

        push @lines, 'Child:';
        for my $child (@{$unit->{Child}}) {
            push @lines, "\t" . "-----------------";
            push @lines, "\t" . 'Info:';
            push @lines, "\t\t" . $child->{info};

            push @lines, "\t" . 'ChildImage:';
            for my $child_image (@{$child->{ChildImage}}) {
                push @lines, "\t\t" . $child_image;
            }

            push @lines, "\t" . 'Commet:';
            for my $comment (@{$child->{Comment}}) {
                push @lines, "\t\t" . $comment;
            }
        }
    }
    return join "\n", @lines;
}

sub delete_objects {
    my %params = @_;

#        users         => \@users,
#        children      => \%children,
#        family_ids    => \@family_ids,
#        comments      => \%comments,
#        child_images  => \%child_images,
#        family_roles  => \%family_roles,
#        tutorial_maps => \%tutorial_maps,
    my %targets = ();
    $targets{User} = [map { $_->{objectId} } @{$params{users}}];

    for my $family_id (@{$params{family_ids}}) {
        # child
        for my $child (@{$params{children}{$family_id}}) {
            $targets{Child} ||= [];
            push @{$targets{Child}}, $child->{objectId};

            # child_image
            my $childImageClass = sprintf('ChildImage%d', $child->{childImageShardIndex});
            $targets{ChildImage} ||= [];
            push @{$targets{ChildImage}}, {
                'className'   => $childImageClass,
                'childImages' => [map { $_->{objectId} } @{$params{child_images}{$child->{objectId}}}],
            };

            # comment
            my $commentClass = sprintf('Comment%d', $child->{commentShardIndex});
            $targets{Comment} ||= [];
            push @{$targets{Comment}}, {
                'className'   => $commentClass,
                'comments' => [map { $_->{objectId} } @{$params{comments}{$child->{objectId}}}],
            };
        }

        # family_role
        $targets{FamilyRole} ||= [];
        push @{$targets{FamilyRole}}, $params{family_roles}{$family_id}{objectId}
            if $params{family_roles}{$family_id}{objectId};

        # tutorial map
        $targets{TutorialMap} ||= [];
        for my $user_id (keys %{$params{tutorial_maps}}) {
            push @{$targets{TutorialMap}}, $params{tutorial_maps}{$user_id}{objectId}
                if $params{tutorial_maps}{$user_id}{objectId};
        }
    }
    delete(%targets);
}

sub delete {
    my %targets = @_;

    my $req = HTTP::Request->new("POST", $URI_DISABLE);
    $req->header(
        'X-Parse-Application-Id' => $APPLICATION_ID,
        'X-Parse-REST-API-Key'   => $CLIENT_KEY,
        'Content-Type'           => 'application/json'
    );
    $req->content( encode_json(\%targets) );
    my $res = $UA->request($req);

    if ($res->is_success) {
        my $content = decode_json($res->content);
        output_log( encode_json($content->{result}) );
        print "normal ended\n";
    } else {
        die $res->message;
    }
}

sub output_log {
    my ($json) = shift;
    my $dt = DateTime->now->set_time_zone('Asia/Tokyo');
    my $log_file_path = File::Spec->catfile($LOG_DIR, sprintf($LOG_FILE_BASE, $dt->ymd('')));

    mkpath $LOG_DIR;

    open my $fh, ">> $log_file_path" or die("Cannot open $log_file_path");
    print $fh join("\t", $dt->strftime('%Y/%m/%d %H:%M:%S'), $json), "\n";
    close $fh;

    print $json, "\n\n";
}


