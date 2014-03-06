#!/usr/bin/env perl
# Mike Covington
# created: 2014-03-05
#
# Description:
#
use strict;
use warnings;
use autodie;
use feature 'say';
use Getopt::Long;
use reproducible;
reproduce();

# default values
my $a = 0;
my $b = 0;
my $c = 0;

my $options = GetOptions (
    "a=s" => \$a,
    "b=s" => \$b,
    "c=s" => \$c,
);

say "a: $a";
say "b: $b";
say "c: $c";
