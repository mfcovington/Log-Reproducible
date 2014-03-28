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
    my $old_repro_file;

    my $warnings = [];
    if ( $cmd =~ /\s-?-reproduce\s+(\S+)/ ) {
        $old_repro_file = $1;
        $cmd = _reproduce_cmd( $prog, $prog_dir, $old_repro_file, $repro_file,
            $warnings );
    }
    _archive_cmd( $cmd, $old_repro_file, $repro_file, $note, $prog_dir, $now,
        $warnings );
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
    my ( $prog, $prog_dir, $old_repro_file, $repro_file, $warnings ) = @_;

    die "Reproducible archive file ($old_repro_file) does not exists.\n"
        unless -e $old_repro_file;
    open my $old_repro_fh, "<", $old_repro_file;
    my @archive = <$old_repro_fh>;
    chomp @archive;
    close $old_repro_fh;

    my $cmd = $archive[0];
    my ( $archived_prog, @args )
        = $cmd =~ /((?:\'[^']+\')|(?:\"[^"]+\")|(?:\S+))/g;
    @ARGV = @args;
    say STDERR "Reproducing archive: $old_repro_file";
    say STDERR "Reproducing command: $cmd";
    _validate_prog_name( $archived_prog, $prog, @args );
    _validate_perl_info( \@archive, $warnings );
    _validate_git_info( \@archive, $prog_dir, $warnings );
    _do_or_die() if scalar @$warnings > 0;
    return $cmd;
}

sub _archive_cmd {
    my ( $cmd, $old_repro_file, $repro_file, $note, $prog_dir, $now,
        $warnings )
        = @_;
    my $error_summary = join "\n", @$warnings;
    my ( $gitcommit, $gitstatus, $gitdiff_cached, $gitdiff )
        = _git_info($prog_dir);
    my ( $perl_path, $perl_version, $perl_inc ) = _perl_info();
    my $cwd = cwd;
    my $full_prog_dir = $prog_dir eq "./" ? $cwd : "$cwd/$prog_dir";
    $full_prog_dir = "$prog_dir ($full_prog_dir)";

    open my $repro_fh, ">", $repro_file;
    say $repro_fh $cmd;
    _add_archive_comment( "NOTE",          $note,           $repro_fh );
    _add_archive_comment( "REPRODUCED",    $old_repro_file, $repro_fh );
    _add_archive_comment( "REPROWARNING",  $error_summary,  $repro_fh );
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
    my ( $archived_prog, $prog, @args ) = @_;
    local $SIG{__DIE__} = sub {warn @_; exit 1};
    die <<EOF if $archived_prog ne $prog;
Current ($prog) and archived ($archived_prog) program names don't match!
If this was expected (e.g., filename was changed), please re-run as:

    perl $prog @args

EOF
}

sub _validate_perl_info {
    my ( $archive_lines, $warnings ) = @_;

    my ($archive_perl_path)
        = _extract_from_archive( $archive_lines, "PERLPATH" );
    my ($archive_perl_version)
        = _extract_from_archive( $archive_lines, "PERLVERSION" );
    my ($archive_perl_inc)
        = _extract_from_archive( $archive_lines, "PERLINC" );

    my ( $perl_path, $perl_version, $perl_inc ) = _perl_info();

    _compare( $archive_perl_path, $perl_path, "PERLPATH", $warnings );
    _compare( $archive_perl_version, $perl_version, "PERLVERSION",
        $warnings );
    _compare( $archive_perl_inc, $perl_inc, "PERLINC", $warnings );
}

sub _validate_git_info {
    my ( $archive_lines, $prog_dir, $warnings ) = @_;

    my ($archive_gitcommit)
        = _extract_from_archive( $archive_lines, "GITCOMMIT" );
    my ($archive_gitstatus)
        = _extract_from_archive( $archive_lines, "GITSTATUS" );
    my ($archive_gitdiff_cached)
        = _extract_from_archive( $archive_lines, "GITDIFFSTAGED" );
    my ($archive_gitdiff)
        = _extract_from_archive( $archive_lines, "GITDIFF" );

    my ( $gitcommit, $gitstatus, $gitdiff_cached, $gitdiff )
        = _git_info($prog_dir);

    _compare( $archive_gitcommit, $gitcommit, "GITCOMMIT", $warnings );
    _compare( $archive_gitstatus, $gitstatus, "GITSTATUS", $warnings );
    _compare( $archive_gitdiff_cached, $gitdiff_cached, "GITDIFFSTAGED",
        $warnings );
    _compare( $archive_gitdiff, $gitdiff, "GITDIFF", $warnings );
}

sub _extract_from_archive {
    my ( $archive_lines, $key ) = @_;

    my @values = grep { /#$key: / } @$archive_lines;
    $_ =~ s/#$key: // for @values;

    return join "\n", @values;
}

sub _compare {
    my ( $archived, $current, $key, $warnings ) = @_;
    chomp $current;
    chomp $archived;

    if ( $archived ne $current ) {
        my $warning_message = "Archived and current $key do NOT match";
        push @$warnings, $warning_message;
        say STDERR "WARNING: $warning_message";
    }
}

sub _do_or_die {
    say STDERR
        "\nThere are inconsistencies between archived and current conditions.";
    print STDERR
        "This may affect reproducibility. Do you want to continue? (y/n) ";
    my $response = <STDIN>;
    if ( $response =~ /^Y(?:ES)?$/i ) {
        return;
    }
    elsif ( $response =~ /^N(?:O)?$/i ) {
        say "Better luck next time...";
        exit;
    }
    else { _do_or_die(); }
}

1;
