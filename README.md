# Log::Reproducible

Increase your reproducibility with the Perl module Log::Reproducible. Set it and forget it... *until you need it!*

## Usage

### Creating Archives

Just add these two lines near the top of your Perl script before accessing `@ARGV` or processing command line options with a module like [Getopt::Long](http://perldoc.perl.org/Getopt/Long.html):

```perl
use Log::Reproducible;
reproduce();
```

Now, every time you run your script, the command line options and other arguments passed to it will be archived in a simple log file whose name reflects the script and the date/time it began running.

For example, running the script `use-reproducible.pl` would result in an archive file named `rlog-use-reproducible.pl-YYYYMMDD.HHMMSS`. If it was run as `use-reproducible.pl -a 1 -b 2 -c 3 OTHER ARGUMENTS`, the contents of the archive file would be just that.

### Reproducing an Archived Analysis

<!-- In order to reproduce an archived run, you can look at the archive contents and re-run the contents; however, that is a waste of time (and has the potential for typos or copy/paste errors).
 -->

To reproduce an archived run, all you need to do is run the script followed by `--reproduce` and the path to the archive file. For example:

```sh
use-reproducible.pl --reproduce rlog-use-reproducible.pl-YYYYMMDD.HHMMSS
```

This results in:

1. The script being executed with the command line options and arguments used in the original archived run
2. The creation of a new archive file identical to the older one (except with an updated date/time in the archive filename)

### Where are the Archives Stored?

#### Default

By default, runs are archived in a directory called `repro-archive` that is created in the current working directory (i.e., whichever directory you were in when you executed your script).

#### Global

You can set a global archive directory with the environmental variable `REPRO_DIR`. Just add the following line to `~/.bash_profile`:

```sh
export REPRO_DIR=/path/to/archive
```

#### Script

You can also set a script-level archive directory by passing the desired directory to the `reproduce()` function in your script:

```perl
reproduce("/path/to/archive");
```

This approach overrides the global archive directory settings.

## Future Features

Some features I may add are:

- Set archive directory with `--reprodir /path/to/archive`
- Add note with `--repronote 'Some comments about the current run'`
- Add verbose mode
    - print to screen the archive name when it gets created
    - print to screen the parameters used when reproducing an archived run
- Standalone script that can be used upstream of any command line functions
