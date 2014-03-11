#!/usr/bin/env perl
# Mike Covington
# created: 2014-03-10
#
# Description:
#
use strict;
use warnings;
use autodie;
use feature 'say';
use Test::More tests => 3;
use FindBin qw($Bin);
use lib "$Bin/../";

#TODO: Account for systems with REPRO_DIR environmental variable set

BEGIN {
    require_ok('Log::Reproducible')
        or BAIL_OUT "Can't load Log::Reproducible";
}

my @got;
my $expected = ["a: 1\n", "b: 'two words'\n", "c: string\n", "extra: some other stuff\n"];
my $script = "perl use-reproducible.pl";

@got = `$script -a 1 -b 'two words' -c string some other stuff`;
is_deeply( \@got, $expected, 'Run and archive Perl script' );

sleep 1;

my $archive_dir = "repro-archive";
my $archive = get_recent_archive($archive_dir);

@got = `$script --reproduce $archive_dir/$archive`;
is_deeply( \@got, $expected, 'Run an archived Perl script' );

sub get_recent_archive {
    my $archive_dir = shift;
    opendir (my $dh, $archive_dir);
    my @archives = grep { /^rlog-/ && -f "$archive_dir/$_" } readdir($dh);
    closedir $dh;
    return pop @archives;
}
