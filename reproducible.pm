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
        if ( defined $ENV{REPRO_DIR} ) {
            $dir = $ENV{REPRO_DIR};
        }
        else {
            my $cwd = getcwd;
            $dir = "$cwd/repro-archive";
        }
    }
    make_path $dir;

    my $prog = $0;
    $prog = basename $prog;
    my $cmd = join " ", $prog, @ARGV;
    my $now = strftime "%Y%m%d.%H%M%S", localtime;
    my $repro_file = "$dir/rlog-$prog-$now";

    if ( $cmd =~ /\s-?-reproduce\s+(\S+)/ ) {
        my $old_repro_file = $1;
        _reproduce_cmd( $prog, $old_repro_file, $repro_file );
    }
    else {
        _archive_cmd( $cmd, $repro_file );
    }
}

sub _reproduce_cmd {
    my ( $prog, $old_repro_file, $repro_file ) = @_;

    die "Reproducible archive file ($old_repro_file) does not exists.\n"
        unless -e $old_repro_file;
    open my $old_repro_fh, "<", $old_repro_file;
    my $cmd = <$old_repro_fh>;
    close $old_repro_fh;
    chomp $cmd;

    my ( $old_prog, @args ) = split /\s/, $cmd;
    @ARGV = @args;
    _validate_prog_name( $old_prog, $prog, @args );
    _archive_cmd( $cmd, $repro_file );
}

sub _archive_cmd {
    my ( $cmd, $repro_file ) = @_;
    open my $repro_fh, ">", $repro_file;
    say $repro_fh $cmd;
    close $repro_fh;
}

sub _validate_prog_name {
    my ( $old_prog, $prog, @args ) = @_;
    die <<EOF if $old_prog ne $prog;
Current ($prog) and archived ($old_prog) program names don't match!
If this was expected (e.g., filename was changed), please re-run as:

    perl $prog @args

EOF
}

1;
