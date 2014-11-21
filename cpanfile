requires 'JSON',                            '2.50';
requires 'Time::Piece',                     '1.20';
requires 'Log::Minimal',                    '0.17';
requires 'DBIx::DBHResolver',               '0.17';
requires 'DBIx::Simple',                    '1.35';
requires 'DBD::mysql',                      '4.025';
requires 'File::Stamped',                   '0.03';
requires 'Path::Class',                     '0.33';
requires 'SQL::Abstract',                   '1.75';
requires 'SQL::Abstract::Plugin::InsertMulti', '0.04';
requires 'String::CamelCase';
requires 'Jcode',                           '2.07';
requires 'MIME::Entity',                    '5.505';
requires 'AWS::CLIWrapper',                 '1.01';
requires 'Data::Dump',                      '1.22';
requires 'Sub::Retry',                      '0.06';
requires 'LWP::Protocol::https',            '6.06';
requires 'Class::Accessor::Lite',           '0.06';

requires 'LWP::UserAgent',                  '6.06';
requires 'HTTP::Request',                   '6.00';
requires 'JSON::XS',                        '3.01';
requires 'Getopt::Long',                    '2.42';
requires 'Term::UI',                        '0.42';
requires 'Term::ReadLine',                  '1.14';
requires 'YAML';
requires 'File::Spec',                      '3.47';
requires 'File::Path',                      '2.09';
requires 'DateTime',                        '1.12';

on configure => sub {
};

on test => sub {
    requires 'Test::Most';
};
