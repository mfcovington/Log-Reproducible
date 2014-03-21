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

# TODO: Set dir with --reprodir XXX
# TODO: Add verbose (or silent) option
# TODO: Standalone script that can be used upstream of any command line functions
# TODO: Archive version # and/or current git SHA1, if available
#         git log -n1 --oneline
#         git diff
#         git status ?
#         -- fatal: Not a git repository (or any of the parent directories): .git

sub first_index (&@) {    # From List::MoreUtils v0.33
    my $f = shift;
    foreach my $i ( 0 .. $#_ ) {
        local *_ = \$_[$i];
        return $i if $f->();
    }
    return -1;
}

sub reproduce {
    my $dir = shift;
    $dir = _set_dir($dir);
    make_path $dir;

    my ( $prog, $cmd, $note ) = _parse_command();
    my $repro_file = _set_repro_file( $dir, $prog );

    if ( $cmd =~ /\s-?-reproduce\s+(\S+)/ ) {
        my $old_repro_file = $1;
        $cmd = _reproduce_cmd( $prog, $old_repro_file, $repro_file );
    }
    _archive_cmd( $cmd, $repro_file, $note );
}

sub _set_dir {
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
    return $dir;
}

sub _parse_command {
    my $note;
    my $note_idx = first_index { $_ =~ /^-?-repronote$/ } @ARGV;
    if ( $note_idx > -1 ) {
        $note = $ARGV[ $note_idx + 1 ];
        splice @ARGV, $note_idx, 2;
    }

    for (@ARGV) {
        $_ = "'$_'" if /\s/;
    }
    my $prog = $0;
    $prog = basename $prog;
    my $cmd = join " ", $prog, @ARGV;
    return $prog, $cmd, $note;
}

sub _set_repro_file {
    my ( $dir, $prog ) = @_;
    my $now = strftime "%Y%m%d.%H%M%S", localtime;
    my $repro_file = "$dir/rlog-$prog-$now";
}

sub _reproduce_cmd {
    my ( $prog, $old_repro_file, $repro_file ) = @_;

    die "Reproducible archive file ($old_repro_file) does not exists.\n"
        unless -e $old_repro_file;
    open my $old_repro_fh, "<", $old_repro_file;
    my $cmd = <$old_repro_fh>;
    close $old_repro_fh;
    chomp $cmd;

    my ( $old_prog, @args ) = $cmd =~ /((?:\'[^']+\')|(?:\"[^"]+\")|(?:\S+))/g;
    @ARGV = @args;
    say STDERR "Reproducing archive: $old_repro_file";
    _validate_prog_name( $old_prog, $prog, @args );
    return $cmd;
}

sub _archive_cmd {
    my ( $cmd, $repro_file, $note ) = @_;
    open my $repro_fh, ">", $repro_file;
    say $repro_fh $cmd;
    if ( defined $note ) {
        my @note_lines = split /\n/, $note;
        say $repro_fh "#NOTE: $_" for @note_lines;
    }
    close $repro_fh;
    say STDERR "Created new archive: $repro_file";
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
