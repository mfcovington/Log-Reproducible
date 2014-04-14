# Log::Reproducible (0.8.1)

Increase your reproducibility with the Perl module Log::Reproducible. 

**TAGLINE:** Set it and forget it... *until you need it!*

**MOTIVATION:** In science (and probably any other analytical field), reproducibility is critical. If an analysis cannot be faithfully reproduced, it was arguably a waste of time.

How does Log::Reproducible increase reproducibility?

- Provides effortless [record keeping](#creating-archives) of the conditions under which scripts are run
- Allows [easy replication](#reproducing-an-archived-analysis) of these conditions
- Detects and [reports inconsistencies](#inconsistencies-between-current-and-archived-conditions) between archived and replicated conditions, including differences in:
    - Perl setup
    - State of the Git repository (if the script is under Git version control)
    - Environmental variables

## Usage

### Creating Archives

Just add a single line near the top of your Perl script before accessing `@ARGV`, calling a module that manipulates `@ARGV`, or processing command line options with a module like [Getopt::Long](http://perldoc.perl.org/Getopt/Long.html):

```perl
use Log::Reproducible;
```

That's all!

Now, every time you run your script, the command line options and other arguments passed to it will be archived in a simple log file whose name reflects the script and the date/time it began running.

#### Other Archive Contents

Also included in the archive are (in order):

- custom notes, if provided (see [Adding Archive Notes](#adding-archive-notes), below)
- the date/time that the script started
- the working directory
- the directory containing the script
- archive version (i.e., Log::Reproducible version)
- Perl-related info (version, path to perl, and `@INC`)
- Git repository info, if applicable (see [Git Repo Info](#git-repo-info), below)
- environmental variables and their values (`%ENV`)
- the exit code
- the date/time that the script finished
- elapsed time

For example, running the script `sample.pl` would result in an archive file named `rlog-sample.pl-YYYYMMDD.HHMMSS`.

If it was run as `perl bin/sample.pl -a 1 -b 2 -c 3 OTHER ARGUMENTS`, the contents of the archive file would look something like:

    sample.pl -a 1 -b 2 -c 3 OTHER ARGUMENTS
    #WHEN: at HH:MM:SS on weekday month day, year
    #WORKDIR: /path/to/working/dir
    #SCRIPTDIR: bin (/path/to/working/dir/bin)
    ################################################################################
    ##################### GOTO END OF FILE FOR EXIT CODE INFO. #####################
    ################################################################################
    #ARCHIVERSION: 0.8.1
    #PERLVERSION: v5.18.2
    #PERLPATH: /path/to/bin/perl
    #PERLINC: /path/to/perl/lib:/path/to/another/perl/lib:.
    #ENV: PATH:/usr/local/bin:/paths/to/more/bins
    ...
    #ENV: _system_name:OSX
    #ENV: _system_version:10.9
    ################################################################################
    ###### IF EXIT CODE IS MISSING, SCRIPT WAS CANCELLED OR IS STILL RUNNING! ######
    ################## TYPICALLY: 0 == SUCCESS AND 255 == FAILURE ##################
    ################################################################################
    #EXITCODE: 0
    #FINISHED: at HH:MM:SS on weekday month day, year
    #ELAPSED: HH:MM:SS

### Reproducing an Archived Analysis

To reproduce an archived run, all you need to do is run the script followed by `--reproduce` and the path to the archive file. For example:

```sh
perl sample.pl --reproduce rlog-sample.pl-YYYYMMDD.HHMMSS
```

This results in:

1. The script being executed with the command line options and arguments used in the original archived run
2. The creation of a new archive file identical to the older one, except with:
    - an updated date and time
    - the addition of /path/to/the/old/archive

#### Inconsistencies between current and archived conditions

When reproducing an archived analysis, warnings will be issued if the current Perl-, Git-, or ENV-related info fails to match that of the archive. Such inconsistencies are potential indicators that an archived analysis will not be reproduced in a faithful manner.

After the warnings have been displayed, there is a prompt for whether to continue reproducing the archived analysis. If the user chooses to continue, all warnings will be logged in the new archive.

If the current script name does not match the archived script name, the reproduced analysis will immediately fail (with instructions on how to proceed).

### Adding Archive Notes

Notes can be added to an archive using `--repronote`:

```sh
perl sample.pl --repronote 'This is a note'
```

If the note contains spaces, it must be surrounded by quotes.

Notes can span multiple lines:

```sh
perl sample.pl --repronote "This is a multi-line note:
The moon had
a cat's mustache
For a second
  — from Book of Haikus by Jack Kerouac"
```

### Where are the Archives Stored?

When creating or reproducing an archive, a status message gets printed to STDERR indicating the archive's location. For example:

    Reproducing archive: /path/to/repro-archive/rlog-sample.pl-20140321.144307
    Created new archive: /path/to/repro-archive/rlog-sample.pl-20140321.144335

#### Default

By default, runs are archived in a directory called `repro-archive` that is created in the current working directory (i.e., whichever directory you were in when you executed your script).

#### Global

You can set a global archive directory with the environmental variable `REPRO_DIR`. Just add the following line to `~/.bash_profile`:

```sh
export REPRO_DIR=/path/to/archive
```

#### Script

You can set a script-level archive directory by passing the desired directory when importing the `Log::Reproducible` module:

```perl
use Log::Reproducible '/path/to/archive';
```

This approach overrides the global archive directory settings.

#### Via Command Line

You can override all other archive directory settings by passing the desired directory on the command line when you run your script:

```sh
perl sample.pl --reprodir /path/to/archive
```

### Git Repo Info

*PSA: If you are writing, editing, or even just using Perl scripts and you are at all concerned about reproducibility, __you should be using [git](http://git-scm.com/)__ (or another version control system)!*

If git is installed on your system and your script resides within a Git repository, a useful collection of info about the current state of the Git repository will be included in the archive:

- Current branch
- Truncated SHA1 hash of most recent commit 
- Commit message of most recent commit 
- List of modified, added, removed, and unstaged files
- A summary of changes to previously committed files (both staged and unstaged)

An example of the Git info from an archive:

    #GITCOMMIT: develop f483a06 Awesome commit message
    #GITSTATUS: M  staged-modified-file
    #GITSTATUS:  M unstaged-modified-file
    #GITSTATUS: A  newly-added-file
    #GITSTATUS: ?? untracked-file
    #GITDIFFSTAGED: diff --git a/staged-modified-file b/staged-modified-file
    #GITDIFFSTAGED: index ce2f709..a04c0f6 100644
    #GITDIFFSTAGED: --- a/staged-modified-file
    #GITDIFFSTAGED: +++ b/staged-modified-file
    #GITDIFFSTAGED: @@ -1,3 +1,3 @@
    #GITDIFFSTAGED:  An unmodified line
    #GITDIFFSTAGED: -A deleted line
    #GITDIFFSTAGED: +An added line
    #GITDIFFSTAGED:  Another unmodified line
    #GITDIFF: diff --git a/unstaged-modified-file b/unstaged-modified-file
    #GITDIFF: index ce2f709..a04c0f6 100644
    #GITDIFF: --- a/unstaged-modified-file
    #GITDIFF: +++ b/unstaged-modified-file
    #GITDIFF: @@ -1,3 +1,3 @@
    #GITDIFF:  An unmodified line
    #GITDIFF: -A deleted line
    #GITDIFF: +An added line
    #GITDIFF:  Another unmodified line

If you are familiar with Git, you will be able to figure out that the Git repository is on the `develop` branch and the most recent commit (`f483a06`) has the message: "Awesome commit message".

In addition to a newly added file and an untracked file, there are two previously-committed modified files. One modified file has subsequently been staged (`staged-modified-file`) and the other is unstaged (`unstaged-modified-file`). Both modified files have had `A deleted line` replaced with `An added line`.

For most purposes, you might not require all of this information; however, if you need to determine the conditions that existed when you ran a script six months ago, these details could be critical!

### Customization of command line options

It is possible to customize the names of the command line options that Log::Reproducible uses. This is important if there is a conflict with the option names of your script. It can also help save time by decreasing the number of keystrokes required. To override one or more of the defaults ([`reprodir`](#via-command-line), [`reproduce`](#reproducing-an-archived-analysis), and [`repronote`](#adding-archive-notes)), pass a hash reference when calling Log::Reproducible from your script:

```perl
use Log::Reproducible {
    dir       => '/path/to/archive',    # see 'Note 2', below
    reprodir  => 'dir',
    reproduce => 'redo',
    repronote => 'note'
};
```

In this example, you would be able to specify a custom archive directory, add a note, and reproduce an analysis from an existing archive like so:

```sh
perl sample.pl --dir /path/to/archive --note 'This is a note' --redo rlog-sample.pl-YYYYMMDD.HHMMSS
```

**Note 1:** Only include `key => 'value'` pairs for the option names you want to customize.

**Note 2:** Assigning a value to the `dir` key is only required if you want to set a script-level archive directory (see [above](#script) for how this is normally accomplished).

**Note 3:** Since `--repronote` is probably used more regularly than the other options, perhaps the most useful customization is:

```perl
use Log::Reproducible { repronote => 'note' };
```

## Installation

`Log::Reproducible` can be installed using the `autobuild.sh` script or by running the following commands:

```sh
perl Build.pl
./Build
./Build test
./Build install
```

## Future Directions

- Standalone script that can be used upstream of any command line functions
- Python version
