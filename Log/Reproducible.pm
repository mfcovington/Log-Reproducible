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

    my ( $prog, $prog_dir, $cmd, $note ) = _parse_command();
    my $repro_file = _set_repro_file( $dir, $prog );

    if ( $cmd =~ /\s-?-reproduce\s+(\S+)/ ) {
        my $old_repro_file = $1;
        $cmd = _reproduce_cmd( $prog, $old_repro_file, $repro_file );
    }
    _archive_cmd( $cmd, $repro_file, $note, $prog_dir );
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
    my $note = _get_note();
    for (@ARGV) {
        $_ = "'$_'" if /\s/;
    }
    my ( $prog, $prog_dir ) = fileparse $0;
    my $cmd = join " ", $prog, @ARGV;
    return $prog, $prog_dir, $cmd, $note;
}

sub _get_note {
    my $note;
    my $note_idx = first_index { $_ =~ /^-?-repronote$/ } @ARGV;
    if ( $note_idx > -1 ) {
        $note = $ARGV[ $note_idx + 1 ];
        splice @ARGV, $note_idx, 2;
    }
    return $note;
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
    my ( $cmd, $repro_file, $note, $prog_dir ) = @_;
    my ( $gitcommit, $gitstatus, $gitdiff ) = _git_info($prog_dir);
    my $cwd = cwd;
    my $full_prog_dir = $prog_dir eq "./" ? $cwd : "$cwd/$prog_dir";
    $full_prog_dir = "$prog_dir ($full_prog_dir)";

    open my $repro_fh, ">", $repro_file;
    say $repro_fh $cmd;
    _add_archive_comment( "NOTE",      $note,          $repro_fh );
    _add_archive_comment( "WORKDIR",   $cwd,           $repro_fh );
    _add_archive_comment( "SCRIPTDIR", $full_prog_dir, $repro_fh );
    _add_archive_comment( "GITCOMMIT", $gitcommit,     $repro_fh );
    _add_archive_comment( "GITSTATUS", $gitstatus,     $repro_fh );
    _add_archive_comment( "GITDIFF",   $gitdiff,       $repro_fh );
    close $repro_fh;
    say STDERR "Created new archive: $repro_file";
}

sub _git_info {
    my $prog_dir = shift;
    return if `which git` eq '';

    my $gitbranch = `cd $prog_dir; git rev-parse --abbrev-ref HEAD 2>&1;`;
    return if $gitbranch =~ /fatal: Not a git repository/;
    chomp $gitbranch;

    my $gitlog    = `cd $prog_dir; git log -n1 --oneline;`;
    my $gitcommit = "$gitbranch $gitlog";
    my $gitstatus = `cd $prog_dir; git status --short;`;
    my $gitdiff   = `cd $prog_dir; git diff;`;
    return $gitcommit, $gitstatus, $gitdiff;
}

sub _add_archive_comment {
    my ( $title, $comment, $repro_fh ) = @_;
    if ( defined $comment ) {
        my @comment_lines = split /\n/, $comment;
        say $repro_fh "#$title: $_" for @comment_lines;
    }
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
