#!/usr/bin/env perl
# Mike Covington
# created: 2014-03-10
#
# Description:
#
use strict;
use warnings;
use Test::More tests => 8;
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

subtest 'Time tests' => sub {
    plan tests => 4;

    my $now = Log::Reproducible::_now();

    like(
        $$now{'timestamp'},
        qr/2\d{3}[01][0-9][0-3][0-9]\.[01][0-9][0-6][0-9][0-6][0-9]/,
        "Test timestamp"
    );
    like(
        $$now{'when'},
        qr/at [01][0-9]:[0-6][0-9]:[0-6][0-9] on \w{3} \w{3} [0-3][0-9], 2\d{3}/,
        "Test 'at time on date'"
    );
    like( $$now{'seconds'}, qr/\d{10}/, "Test seconds" );

    my $start_seconds  = 1000000;
    my $finish_seconds = 3356330;
    my $elapsed
        = Log::Reproducible::_elapsed( $start_seconds, $finish_seconds );
    is( $elapsed, '654:32:10', 'Test elapsed time' );
};

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
        'repronote', $argv_current );

    is( $prog,             "script.pl", "Script name" );
    is( $prog_dir,         "/path/to/", "Script directory" );
    is( $$current{'NOTE'}, "test note", "Repro note" );
    is( $$current{'CMD'}, "$prog -a 1 -b 'a test' some arguments",
        "Full command" );
};

subtest '_divider_message tests' => sub {
    plan tests => 4;

    my $message;
    $message = Log::Reproducible::_divider_message("X" x 18);
    is($message, join (" ", "#" x 30, "X" x 18, "#" x 30) . "\n", 'Even length message');

    $message = Log::Reproducible::_divider_message("X" x 19);
    is($message, join (" ", "#" x 30, "X" x 19, "#" x 29) . "\n", 'Odd length message');

    $message = Log::Reproducible::_divider_message();
    is($message, "#" x 80 . "\n", 'Divider line only, no message');

    $message = Log::Reproducible::_divider_message("X" x 100);
    is($message, "X" x 100 . "\n", 'Message longer than width (80)');
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
    Log::Reproducible::_set_dir( \$$test_params{'dir'}, 'reprodir',
        $$test_params{'args'} );
    is( $$test_params{'dir'}, $$test_params{'expected'},
        $$test_params{'name'} );
}
