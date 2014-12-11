package BabyryUtils::ConfigLoader;

use strict;
use warnings;
use utf8;

use BabyryUtils;
use Class::Accessor::Lite (
    ro => [qw/config db_config/],
);

use Log::Minimal;

our $__CONFIG;

sub new {
    my $class = shift;
    my $env   = shift;

    $__CONFIG    ||= _load($env);
    my $self = {
        config => $__CONFIG,
    };
    bless $self, $class;
    $self;
}

sub _load {
    my ($env) = @_;

    my $config_path = sprintf('%s/conf/%s.conf', BabyryUtils->base_dir, $env);

    croakf('config file not found path:%s', $config_path)
        unless -f $config_path;

    my $config = do($config_path);
    return $config;
}

1;

