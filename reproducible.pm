# Mike Covington
# created: 2014-03-05
#
# Description:
#
use strict;
use warnings;
use autodie;
use feature 'say';
use Cwd;
use File::Path 'make_path';
use File::Basename;
use POSIX qw(strftime);

sub reproduce {
    my $dir = shift;
    if ( !defined $dir ) {
        my $cwd = getcwd;
        $dir = "$cwd/repro-archive";
    }
    make_path $dir;

    my $prog = $0;
    $prog = basename $prog;
    my $cmd = join " ", $prog, @ARGV;
    my $now = strftime "%Y%m%d.%H%M%S", localtime;
    my $repro_file = "$dir/rlog-$prog-$now";

    if ( $cmd =~ /\s-?-reproduce\s+(\S+)/ ) {
        my $old_repro_file = $1;
        _reproduce_cmd($old_repro_file, $repro_file);
    }
    else {
        _archive_cmd( $cmd, $repro_file );
    }
}

sub _reproduce_cmd {
    my ( $old_repro_file, $repro_file ) = @_;

    die "Reproducible archive file ($old_repro_file) does not exists.\n"
        unless -e $old_repro_file;
    open my $old_repro_fh, "<", $old_repro_file;
    my $cmd = <$old_repro_fh>;
    close $old_repro_fh;
    chomp $cmd;

    _archive_cmd( $cmd, $repro_file );
    my @args = split /\s/, $cmd;
    shift @args;
    @ARGV = @args;
}

sub _archive_cmd {
    my ( $cmd, $repro_file ) = @_;
    open my $repro_fh, ">", $repro_file;
    say $repro_fh $cmd;
    close $repro_fh;
}

1;
