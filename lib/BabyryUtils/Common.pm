package BabyryUtils::Common;

use strict;
use warnings;
use utf8;

use parent qw/BabyryUtils/;
use Log::Minimal;
use BabyryUtils::ConfigLoader;

our $__KEYVAULT;

sub env {
    my $env_file = '/etc/.secret/babyry_env';
    croakf("$env_file not found") if ! -f $env_file;

    open my $fh, "< $env_file" or croakf("Cannot open $env_file");
    my $env_string = (map { chomp; $_ } <$fh>)[0];
    close $fh;

    unless ( $env_string &&
        (
            $env_string eq 'production'  ||
            $env_string eq 'development' ||
            $env_string eq 'local'
        )
    ) {
        croakf('Invalid env : %s', $env_string || '');
    }

    $env_string;
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

