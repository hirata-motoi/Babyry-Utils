package BabyryUtils;

use strict;
use warnings;
use utf8;

our $VERSION='0.01';
use 5.008001;
use Sys::Hostname qw/hostname/;
use File::Stamped;
use Carp;
use Encode;
use Log::Minimal;
use FindBin;

use parent qw/Amon2/;

# Enable project local mode.
#__PACKAGE__->make_local_context();
#
{
    my $base_dir = __PACKAGE__->base_dir;
    my $fh = File::Stamped->new(pattern => $base_dir . "/log/babyry_utils.log.%Y%m%d");
    my $hostname = hostname;
    $Log::Minimal::ESCAPE_WHITESPACE = 0; # enable to separete log by tab
    $Log::Minimal::PRINT = sub {
        my ($time, $type, $message, $trace) = @_;
        print {$fh} decode_utf8(sprintf("(%s) %s [%s] %s at %s\n", $hostname, $time, $type, $message, $trace));
        print decode_utf8(sprintf("(%s) %s [%s] %s at %s\n", $hostname, $time, $type, $message, $trace)) if $ENV{DEBUG};
    };
}

1;

