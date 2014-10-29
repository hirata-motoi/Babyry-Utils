package BabyryUtils::Common;

use strict;
use warnings;
use utf8;

use parent qw/BabyryUtils/;
use Log::Minimal;
use BabyryUtils::ConfigLoader;

our $__KEYVAULT;

sub env {
    return 'local' if !$ENV{APP_ENV};
    return $ENV{APP_ENV} eq 'production' ? 'production' :
           $ENV{APP_ENV} eq 'development' ? 'development' :
           'local' ;
}

sub config { BabyryUtils::ConfigLoader->new(env())->config }

sub get_key_vault {
    my ($class, $key) = @_;
    _load_keyvault() unless $__KEYVAULT;
    return exists $__KEYVAULT->{$key}
        ? $__KEYVAULT->{$key}
        : croakf("get_key_vault failed. key: $key");
}
sub _load_keyvault {
    my $config_full_path = sprintf('%s/%s',
        BabyryUtils->base_dir,
        BabyryUtils::Common->config->{key_vault_config}
    );
    croakf( sprintf('keyvault config file not found. path: %s', $config_full_path))
        unless -f $config_full_path;
    $__KEYVAULT = do( $config_full_path );
}

sub db_config { ProtoServer::ConfigLoader->new(env())->db_config }

1;

