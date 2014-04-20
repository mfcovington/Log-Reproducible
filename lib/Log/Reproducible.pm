package Log::Reproducible;
use strict;
use warnings;
use Cwd;
use File::Path 'make_path';
use File::Basename;
use POSIX qw(strftime difftime ceil floor);
use Config;
use Carp;

# TODO: Test whether potentially conflicting module has already been called
# TODO: Add verbose (or silent) option
# TODO: Standalone script that can be used upstream of any command line functions
# TODO: Auto-build README using POD

our $VERSION = '0.8.1';

=head1 NAME

Log::Reproducible - Effortless record-keeping and enhanced reproducibility. Set it and forget it... until you need it!

=head1 AUTHOR

Michael F. Covington <mfcovington@gmail.com>

=cut

use File::Temp ();
use IPC::Open3;


sub _check_for_known_conflicting_modules {
    my @known_conflicts = @_;

    # Only check for conflicts if Module::Loaded is available (i.e. >= 5.9.4)
    eval "use Module::Loaded";
    return if $@;
    require Module::Loaded;

    my @loaded_conflicts;
    for (@known_conflicts) {
        push @loaded_conflicts, $_ if defined is_loaded($_);
    }

    if ( scalar @loaded_conflicts > 0 ) {
        my $conflict_warning = <<EOF;

WARNING:
A module that accesses '\@ARGV' has been loaded before Log::Reproducible.
To avoid potential conflicts, we recommended changing your script such
that Log::Reproducible is imported before the following module(s):

EOF
        $conflict_warning .= "    $_\n" for sort @loaded_conflicts;
        carp "$conflict_warning\nThis warning originated";
    }
}

sub _check_for_potentially_conflicting_modules {
    my $code = do { open my $fh, '<', $0; local $/; <$fh> };
    my ($code_to_test) = $code =~ /(\A .*?) use \s+ @{[__PACKAGE__]}/sx;
    my ( $temp_fh, $temp_filename ) = File::Temp::tempfile();
    print $temp_fh $code_to_test;

    local ( *CIN, *COUT, *CERR );
    my $cmd = "$^X -MO=Xref,-r $temp_filename";
    my $pid = open3( \*CIN, \*COUT, \*CERR, $cmd );

    my $re
        = '(?:'
        . join( '|' => map { /^(?:\.[\\\/]?)?(.*)$/; "\Q$1" } @INC )
        . ')[\\\/]?(\S+?)(?:\.\S+)?\s';
    my %argv_modules;

    for (<COUT>) {
        next unless /\@\s+ARGV/;
        ( my $module ) = /$re/;
        $module =~ s{[\\\/]}{::}g;
        ++$argv_modules{$module};
    }

    waitpid $pid, 0;

    my @warn_modules = sort keys %argv_modules;

    if (@warn_modules) {
        warn "WARNING:\n",
            "Modules using '\@ARGV' before " . __PACKAGE__ . " loaded:\n";
        warn "\t$_\n" for @warn_modules;
    }
}

BEGIN {
    _check_for_known_conflicting_modules( '', '' );    # Add when discovered
    _check_for_potentially_conflicting_modules();
}

sub import {
    my ( $pkg, $custom_repro_opts ) = @_;
    reproduce($custom_repro_opts);
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
    my $custom_repro_opts = shift;

    my $repro_opts     = _parse_custom_repro_opts($custom_repro_opts);
    my $dir            = $$repro_opts{dir};
    my $full_prog_name = $0;
    my $argv_current   = \@ARGV;
    _set_dir( \$dir, $$repro_opts{reprodir}, $argv_current );
    make_path $dir;

    my $current = {};
    my ( $prog, $prog_dir )
        = _parse_command( $current, $full_prog_name, $$repro_opts{repronote},
        $argv_current );
    my ( $repro_file, $start ) = _set_repro_file( $current, $dir, $prog );
    _get_current_state( $current, $prog_dir );

    my $categories = {
        script => [
            'NOTE',    'REPRODUCED', 'REPROWARNING', 'STARTED',
            'WORKDIR', 'SCRIPTDIR'
        ],
        system => [
            'ARCHIVERSION', 'PERLVERSION', 'PERLPATH',      'PERLINC',
            'GITCOMMIT',    'GITSTATUS',   'GITDIFFSTAGED', 'GITDIFF',
            'ENV'
        ],
    };
    my $warnings = [];

    my $reproduce_opt = $$repro_opts{reproduce};
    if ( $$current{'CMD'} =~ /\s-?-$reproduce_opt\s+(\S+)/ ) {
        my $old_repro_file = $1;
        $$current{'REPRODUCED'} = $old_repro_file;
        $$current{'CMD'}
            = _reproduce_cmd( $current, $prog, $prog_dir, $old_repro_file,
            $repro_file, $argv_current, $categories, $warnings );
    }
    _archive_cmd( $current, $repro_file, $prog_dir, $start, $categories,
        $warnings );
    _exit_code( $repro_file, $start );
}

sub _parse_custom_repro_opts {
    my $custom_repro_opts   = shift;

    my %default_opts = (
        dir       => undef,
        reprodir  => 'reprodir',
        reproduce => 'reproduce',
        repronote => 'repronote'
    );

    if ( ! defined $custom_repro_opts) {
        return \%default_opts;
    }
    elsif ( ref($custom_repro_opts) eq 'HASH' ) {
        for my $opt ( keys %default_opts ) {
            $$custom_repro_opts{$opt} = $default_opts{$opt}
                unless exists $$custom_repro_opts{$opt};
        }
        return $custom_repro_opts;
    }
    else {
        $default_opts{dir} = $custom_repro_opts;
        return \%default_opts;
    }
}

sub _set_dir {
    my ( $dir, $reprodir_opt, $argv_current ) = @_;
    my $cli_dir = _get_repro_arg( $reprodir_opt, $argv_current );

    if ( defined $cli_dir ) {
        $$dir = $cli_dir;
    }
    elsif ( !defined $$dir ) {
        if ( defined $ENV{REPRO_DIR} ) {
            $$dir = $ENV{REPRO_DIR};
        }
        else {
            my $cwd = getcwd;
            $$dir = "$cwd/repro-archive";
        }
    }
}

sub _parse_command {
    my ( $current, $full_prog_name, $repronote_opt, $argv_current ) = @_;
    $$current{'NOTE'} = _get_repro_arg( $repronote_opt, $argv_current );
    for (@$argv_current) {
        $_ = "'$_'" if /\s/;
    }
    my ( $prog, $prog_dir ) = fileparse $full_prog_name;
    $$current{'CMD'} = join " ", $prog, @$argv_current;
    return $prog, $prog_dir;
}

sub _get_repro_arg {
    my ( $repro_opt, $argv_current ) = @_;
    my $repro_arg;
    my $argv_idx = _first_index { $_ =~ /^-?-$repro_opt$/ } @$argv_current;
    if ( $argv_idx > -1 ) {
        $repro_arg = $$argv_current[ $argv_idx + 1 ];
        splice @$argv_current, $argv_idx, 2;
    }
    return $repro_arg;
}

sub _set_repro_file {
    my ( $current, $dir, $prog ) = @_;
    my $start = _now();
    $$current{'STARTED'} = $$start{'when'};
    my $repro_file = "$dir/rlog-$prog-" . $$start{'timestamp'};
    return $repro_file, $start;
}

sub _now {
    my %now;
    my @localtime = localtime;
    $now{'timestamp'} = strftime "%Y%m%d.%H%M%S",         @localtime;
    $now{'when'}      = strftime "at %X on %a %b %d, %Y", @localtime;
    $now{'seconds'}   = time();
    return \%now;
}

sub _reproduce_cmd {
    my ( $current, $prog, $prog_dir, $old_repro_file, $repro_file,
        $argv_current, $categories, $warnings )
        = @_;

    open my $old_repro_fh, "<", $old_repro_file
        or die "Cannot open $old_repro_file for reading: $!\n";
    my @archive = <$old_repro_fh>;
    chomp @archive;
    close $old_repro_fh;

    my $cmd = $archive[0];
    my ( $archived_prog, @archived_argv )
        = $cmd =~ /((?:\'[^']+\')|(?:\"[^"]+\")|(?:\S+))/g;
    @$argv_current = @archived_argv;
    print STDERR "Reproducing archive: $old_repro_file\n";
    print STDERR "Reproducing command: $cmd\n";
    _validate_prog_name( $archived_prog, $prog, @archived_argv );
    _validate_archived_info( \@archive, $current, $categories, $warnings );
    _do_or_die() if scalar @$warnings > 0;
    return $cmd;
}

sub _archive_cmd {
    my ( $current, $repro_file, $prog_dir, $start, $categories, $warnings )
        = @_;
    my $error_summary = join "\n", @$warnings;

    open my $repro_fh, ">", $repro_file
        or die "Cannot open $repro_file for writing: $!";
    print $repro_fh $$current{'CMD'}, "\n";

    _add_archive_comment( $_, $$current{$_}, $repro_fh )
        for @{ $$categories{'script'} };
    _add_divider($repro_fh);
    _add_archive_comment( $_, $$current{$_}, $repro_fh )
        for @{ $$categories{'system'} };
    _add_exit_code_preamble($repro_fh);
    close $repro_fh;
    print STDERR "Created new archive: $repro_file\n";
}

sub _get_current_state {
    my ( $current, $prog_dir ) = @_;
    _archive_version($current);
    _git_info( $current, $prog_dir );
    _perl_info($current);
    _dir_info( $current, $prog_dir );
    _env_info($current);
}

sub _archive_version {
    my $current = shift;
    $$current{'ARCHIVERSION'} = $VERSION;
}

sub _git_info {
    my ( $current, $prog_dir ) = @_;
    return if `which git` eq '';

    my $gitbranch = `cd $prog_dir; git rev-parse --abbrev-ref HEAD 2>&1;`;
    return if $gitbranch =~ /fatal: Not a git repository/;
    chomp $gitbranch;

    my $gitlog = `cd $prog_dir; git log -n1 --oneline;`;
    $$current{'GITCOMMIT'}     = "$gitbranch $gitlog";
    $$current{'GITSTATUS'}     = `cd $prog_dir; git status --short;`;
    $$current{'GITDIFFSTAGED'} = `cd $prog_dir; git diff --cached;`;
    $$current{'GITDIFF'}       = `cd $prog_dir; git diff;`;
}

sub _perl_info {
    my $current = shift;
    $$current{'PERLPATH'}    = $Config{perlpath};
    $$current{'PERLVERSION'} = sprintf "v%vd", $^V;
    $$current{'PERLINC'}     = join ":", @INC;
}

sub _dir_info {
    my ( $current, $prog_dir ) = @_;

    my $cwd = cwd;
    my $absolute_prog_dir;

    if ( $prog_dir eq "./" ) {
        $absolute_prog_dir = $cwd;
    }
    elsif ( $prog_dir =~ /^\// ) {
        $absolute_prog_dir = $prog_dir;
    }
    else {
        $absolute_prog_dir = "$cwd/$prog_dir";
    }
    my $script_dir = "$prog_dir ($absolute_prog_dir)";

    $$current{'WORKDIR'}   = $cwd;
    $$current{'SCRIPTDIR'} = $script_dir;
}

sub _env_info {
    my $current = shift;
    $$current{'ENV'} = join "\n", map {"$_:$ENV{$_}"} sort keys %ENV;
}

sub _add_archive_comment {
    my ( $title, $comment, $repro_fh ) = @_;
    if ( defined $comment ) {
        my @comment_lines = split /\n/, $comment;
        print $repro_fh "#$title: $_\n" for @comment_lines;
    }
}

sub _add_divider {
    my $repro_fh = shift;
    print $repro_fh _divider_message();
    print $repro_fh _divider_message("GOTO END OF FILE FOR EXIT CODE INFO.");
    print $repro_fh _divider_message();
}

sub _add_exit_code_preamble {
    my $repro_fh = shift;
    print $repro_fh _divider_message();
    print $repro_fh _divider_message(
        "IF EXIT CODE IS MISSING, SCRIPT WAS CANCELLED OR IS STILL RUNNING!");
    print $repro_fh _divider_message(
        "TYPICALLY: 0 == SUCCESS AND 255 == FAILURE");
    print $repro_fh _divider_message();
    print $repro_fh "#EXITCODE: ";
}

sub _divider_message {
    my $message = shift;
    my $width   = 80;
    if ( defined $message ) {
        my $msg_len = length($message) + 2;
        my $pad     = ( $width - $msg_len ) / 2;
        $message
            = $pad > 0
            ? join " ", "#" x ceil($pad), $message, "#" x floor($pad)
            : $message;
    }
    else {
        $message = "#" x $width;
    }
    return "$message\n";
}

sub _validate_prog_name {
    my ( $archived_prog, $prog, @args ) = @_;
    local $SIG{__DIE__} = sub { warn @_; exit 1 };
    die <<EOF if $archived_prog ne $prog;
Current ($prog) and archived ($archived_prog) program names don't match!
If this was expected (e.g., filename was changed), please re-run as:

    perl $prog @args

EOF
}

sub _validate_archived_info {
    my ( $archive_lines, $current, $categories, $warnings ) = @_;

    for ( @{ $$categories{'system'} } ) {
        my ($archived) = _extract_from_archive( $archive_lines, $_ );
        _compare_archive_current( $archived, $current, $_, $warnings );
    }
}

sub _extract_from_archive {
    my ( $archive_lines, $key ) = @_;

    my @values = grep {/^#$key: /} @$archive_lines;
    $_ =~ s/^#$key: // for @values;

    return join "\n", @values;
}

sub _compare_archive_current {
    my ( $archived, $current, $key, $warnings ) = @_;
    my $current_value = $$current{$key};
    return unless defined $current_value;
    chomp $current_value;
    chomp $archived;

    if ( $archived ne $current_value ) {
        my $warning_message = "Archived and current $key do NOT match";
        push @$warnings, $warning_message;
        print STDERR "WARNING: $warning_message\n";
    }
}

sub _do_or_die {
    print STDERR
        "\nThere are inconsistencies between archived and current conditions.\n";
    print STDERR
        "This may affect reproducibility. Do you want to continue? (y/n) ";
    my $response = <STDIN>;
    if ( $response =~ /^Y(?:ES)?$/i ) {
        return;
    }
    elsif ( $response =~ /^N(?:O)?$/i ) {
        print "Better luck next time...\n";
        exit;
    }
    else { _do_or_die(); }
}

sub _exit_code {
    our ( $repro_file, $start ) = @_;

    END {
        return unless defined $repro_file;
        my $finish = _now();
        my $elapsed = _elapsed( $$start{'seconds'}, $$finish{'seconds'} );
        open my $repro_fh, ">>", $repro_file
            or die "Cannot open $repro_file for appending: $!";
        print $repro_fh "$?\n";    # This completes EXITCODE line
        _add_archive_comment( "FINISHED", $$finish{'when'}, $repro_fh );
        _add_archive_comment( "ELAPSED",  $elapsed,         $repro_fh );
        close $repro_fh;
    }
}

sub _elapsed {
    my ( $start_seconds, $finish_seconds ) = @_;

    my $secs = difftime $finish_seconds, $start_seconds;
    my $mins = int $secs / 60;
    $secs = $secs % 60;
    my $hours = int $mins / 60;
    $mins = $mins % 60;

    return join ":", map { sprintf "%02d", $_ } $hours, $mins, $secs;
}

1;
