#!/usr/bin/env perl
# Mike Covington
# created: 2014-03-10
#
# Description:
#
use strict;
use warnings;
use Test::More tests => 6;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Cwd;

# TODO: Account for systems with REPRO_DIR environmental variable set
# TODO: Need to update tests to account for new features

BEGIN {
    require_ok('Log::Reproducible')
        or BAIL_OUT "Can't load Log::Reproducible";
}
my $cwd = getcwd;

my @got;
my $expected = [
    "a: 1\n",
    "b: 'two words'\n",
    "c: string\n",
    "extra: some other stuff\n"
];
my $script      = "test-reproducible.pl";
my $archive_dir = "$Bin/repro-archive";
my $cmd         = "perl $Bin/$script --reprodir $archive_dir";

@got = `$cmd -a 1 -b 'two words' -c string some other stuff 2> /dev/null`;
is_deeply( \@got, $expected, 'Run and archive Perl script' );

sleep 1;

my $archive = get_recent_archive($archive_dir);
@got = `$cmd --reproduce $archive_dir/$archive 2> /dev/null`;
is_deeply( \@got, $expected, 'Run an archived Perl script' );

subtest '_set_dir tests' => sub {
    plan tests => 4;

    my $original_REPRO_DIR = $ENV{REPRO_DIR};
    undef $ENV{REPRO_DIR};

    my $test_params = {};
    $test_params = {
        name     => "default _set_dir()",
        dir      => undef,
        args     => undef,
        expected => "$cwd/repro-archive",
    };
    test_set_dir($test_params);

    my $custom_dir = "custom-dir";
    $test_params = {
        name     => "_set_dir('$custom_dir')",
        dir      => $custom_dir,
        args     => undef,
        expected => $custom_dir,
    };
    test_set_dir($test_params);

    my $cli_dir = "cli-dir";
    $test_params = {
        name     => "_set_dir() using '--reprodir $cli_dir' on CLI",
        dir      => undef,
        args     => [ '--reprodir', $cli_dir ],
        expected => $cli_dir,
    };
    test_set_dir($test_params);

    my $env_dir = "env-dir";
    $ENV{REPRO_DIR} = $env_dir;
    $test_params = {
        name =>
            "_set_dir() using REPRO_DIR environmental variable ('$env_dir')",
        dir      => undef,
        args     => undef,
        expected => $env_dir,
    };
    test_set_dir($test_params);
    $ENV{REPRO_DIR} = $original_REPRO_DIR;
};

subtest '_get_repro_arg tests' => sub {
    plan tests => 3;

    my $argv_current = [
        '--repronote', 'test note',
        '--reprodir',  '/path/to/archive',
        '-a',          '1',
        '-b',          'a test',
        'some',        'arguments'
    ];

    my $arg;
    $arg = Log::Reproducible::_get_repro_arg( "repronote", $argv_current );
    is( $arg, 'test note', "Get note from CLI ('--repronote')" );
    $arg = Log::Reproducible::_get_repro_arg( "reprodir", $argv_current );
    is( $arg, '/path/to/archive', "Get directory from CLI ('--reprodir')" );
    is_deeply(
        $argv_current,
        [ '-a', '1', '-b', 'a test', 'some', 'arguments' ],
        "Leftover options/arguments"
    );
};

subtest '_parse_command tests' => sub {
    plan tests => 4;

    my $current      = {};
    my $argv_current = [
        '--repronote', 'test note', '-a',   '1',
        '-b',          'a test',    'some', 'arguments'
    ];
    my $full_prog_name = "/path/to/script.pl";
    my ( $prog, $prog_dir )
        = Log::Reproducible::_parse_command( $current, $full_prog_name,
        $argv_current );

    is( $prog,             "script.pl", "Script name" );
    is( $prog_dir,         "/path/to/", "Script directory" );
    is( $$current{'NOTE'}, "test note", "Repro note" );
    is( $$current{'CMD'}, "$prog -a 1 -b 'a test' some arguments",
        "Full command" );
};

exit;

sub get_recent_archive {
    my $archive_dir = shift;
    opendir (my $dh, $archive_dir) or die "Cannot opendir $archive_dir: $!";
    my @archives = grep { /^rlog-$script/ && -f "$archive_dir/$_" } readdir($dh);
    closedir $dh;
    return pop @archives;
}

sub test_set_dir {
    my $test_params = shift;
    Log::Reproducible::_set_dir( \$$test_params{'dir'},
        $$test_params{'args'} );
    is( $$test_params{'dir'}, $$test_params{'expected'},
        $$test_params{'name'} );
}
