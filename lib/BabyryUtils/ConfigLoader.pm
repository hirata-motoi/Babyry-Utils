package BabyryUtils::ConfigLoader;

use strict;
use warnings;
use utf8;

use BabyryUtils;
use Class::Accessor::Lite (
    ro => [qw/config db_config/],
);
use Carp;

use Log::Minimal;

our $__CONFIG;
our $__DB_CONFIG;

sub new {
    my $class = shift;
    my $env   = shift;

    $__CONFIG    ||= _load($env);
    $__DB_CONFIG ||= _load($env, 'db');

    my $self = {
        config => $__CONFIG,
        db_config => $__DB_CONFIG,
    };
    bless $self, $class;
    $self;
}

sub _load {
    my ($env, $type) = @_;

    my $config_path = $type && $type eq 'db'
        ? sprintf('%s/conf/db/%s.conf', BabyryUtils->base_dir, $env)
        : sprintf('%s/conf/%s.conf', BabyryUtils->base_dir, $env);

    croak('config file not found type:%s path:%s', ($type || 'config'), $config_path)
        unless -f $config_path;

    my $config = do($config_path);
    return $config;
}

1;

