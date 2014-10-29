requires 'JSON',                            '2.50';
requires 'Time::Piece',                     '1.20';
requires 'Log::Minimal',                    '0.17';
requires 'DBIx::DBHResolver',               '0.17';
requires 'DBIx::Simple',                    '1.35';
requires 'DateTime',                        '1.06';
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

requires 'LWP::UserAgent';
requires 'HTTP::Request';
requires 'JSON::XS';
requires 'Getopt::Long';
requires 'Term::UI';
requires 'Term::ReadLine';
requires 'YAML';
requires 'Amon2';

on configure => sub {
};

on test => sub {
    requires 'Test::Most';
};
