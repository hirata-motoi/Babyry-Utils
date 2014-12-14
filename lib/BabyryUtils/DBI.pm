package BabyryUtils::DBI;

use 5.014;
use warnings;

use Carp;
use DBIx::DBHResolver;
use BabyryUtils;
use BabyryUtils::Common;
use YAML;

our $resolver;


sub resolver {
    my ($self, $db_name) = @_;

    if (!$resolver) {
        $resolver = DBIx::DBHResolver->new;
        my $db_config = BabyryUtils::Common->db_config;
        for my $handle (keys %{$db_config->{connect_info}}) {
            for my $key (keys %{$db_config->{connect_info}{$handle}}) {
                next if $key ne 'dsn';
                $db_config->{connect_info}{$handle}{$key}
                    = sprintf $db_config->{connect_info}{$handle}{$key}, $db_name;
            }
        }

        $resolver->config($db_config);
    }
    return $resolver;
}

1;
