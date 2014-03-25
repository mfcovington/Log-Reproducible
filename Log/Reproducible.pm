package Log::Reproducible;
use strict;
use warnings;
use autodie;
use feature 'say';
use Cwd;
use File::Path 'make_path';
use File::Basename;
use POSIX qw(strftime);
use Config;

# TODO: Add verbose (or silent) option
# TODO: Standalone script that can be used upstream of any command line functions
# TODO: Allow customizion of --repronote/--reprodir/--reproduce upon import (to avoid conflicts or just shorten)

sub import {
    my ( $pkg, $dir ) = @_;
    reproduce($dir);
}

sub _first_index (&@) {    # From v0.33 of the wonderful List::MoreUtils
    my $f = shift;         # https://metacpan.org/pod/List::MoreUtils
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
    my ( $repro_file, $now ) = _set_repro_file( $dir, $prog );

    if ( $cmd =~ /\s-?-reproduce\s+(\S+)/ ) {
        my $old_repro_file = $1;
        $cmd = _reproduce_cmd( $prog, $old_repro_file, $repro_file );
    }
    _archive_cmd( $cmd, $repro_file, $note, $prog_dir, $now );
}

sub _set_dir {
    my $dir     = shift;
    my $cli_dir = _get_repro_arg("reprodir");

    if ( defined $cli_dir ) {
        $dir = $cli_dir;
    }
    elsif ( !defined $dir ) {
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
    my $note = _get_repro_arg("repronote");
    for (@ARGV) {
        $_ = "'$_'" if /\s/;
    }
    my ( $prog, $prog_dir ) = fileparse $0;
    my $cmd = join " ", $prog, @ARGV;
    return $prog, $prog_dir, $cmd, $note;
}

sub _get_repro_arg {
    my $repro_arg = shift;
    my $arg;
    my $arg_idx = _first_index { $_ =~ /^-?-$repro_arg$/ } @ARGV;
    if ( $arg_idx > -1 ) {
        $arg = $ARGV[ $arg_idx + 1 ];
        splice @ARGV, $arg_idx, 2;
    }
    return $arg;
}

sub _set_repro_file {
    my ( $dir, $prog ) = @_;
    my $now = strftime "%Y%m%d.%H%M%S", localtime;
    my $repro_file = "$dir/rlog-$prog-$now";
    return $repro_file, $now;
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
    my ( $cmd, $repro_file, $note, $prog_dir, $now ) = @_;
    my ( $gitcommit, $gitstatus, $gitdiff_cached, $gitdiff )
        = _git_info($prog_dir);
    my ( $perl_path, $perl_version, $perl_inc ) = _perl_info();
    my $cwd = cwd;
    my $full_prog_dir = $prog_dir eq "./" ? $cwd : "$cwd/$prog_dir";
    $full_prog_dir = "$prog_dir ($full_prog_dir)";

    open my $repro_fh, ">", $repro_file;
    say $repro_fh $cmd;
    _add_archive_comment( "NOTE",          $note,           $repro_fh );
    _add_archive_comment( "WHEN",          $now,            $repro_fh );
    _add_archive_comment( "WORKDIR",       $cwd,            $repro_fh );
    _add_archive_comment( "SCRIPTDIR",     $full_prog_dir,  $repro_fh );
    _add_archive_comment( "PERLVERSION",   $perl_version,   $repro_fh );
    _add_archive_comment( "PERLPATH",      $perl_path,      $repro_fh );
    _add_archive_comment( "PERLINC",       $perl_inc,       $repro_fh );
    _add_archive_comment( "GITCOMMIT",     $gitcommit,      $repro_fh );
    _add_archive_comment( "GITSTATUS",     $gitstatus,      $repro_fh );
    _add_archive_comment( "GITDIFFSTAGED", $gitdiff_cached, $repro_fh );
    _add_archive_comment( "GITDIFF",       $gitdiff,        $repro_fh );
    close $repro_fh;
    say STDERR "Created new archive: $repro_file";
}

sub _git_info {
    my $prog_dir = shift;
    return if `which git` eq '';

    my $gitbranch = `cd $prog_dir; git rev-parse --abbrev-ref HEAD 2>&1;`;
    return if $gitbranch =~ /fatal: Not a git repository/;
    chomp $gitbranch;

    my $gitlog         = `cd $prog_dir; git log -n1 --oneline;`;
    my $gitcommit      = "$gitbranch $gitlog";
    my $gitstatus      = `cd $prog_dir; git status --short;`;
    my $gitdiff_cached = `cd $prog_dir; git diff --cached;`;
    my $gitdiff        = `cd $prog_dir; git diff;`;
    return $gitcommit, $gitstatus, $gitdiff_cached, $gitdiff;
}

sub _perl_info {
    my $perl_path    = $Config{perlpath};
    my $perl_version = $^V;
    my $perl_inc     = join ":", @INC;
    return $perl_path, $perl_version, $perl_inc;
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
