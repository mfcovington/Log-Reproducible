---
layout:  post
title:   Inconsistencies During Reproduction
to_prev: reproduce
to_next: notes
---
When reproducing an archived analysis, warnings will be issued if the current Perl-, Git-, or ENV-related info fails to match that of the archive. Such inconsistencies are potential indicators that an archived analysis will not be reproduced in a faithful manner.

If the Perl module [Text::Diff](https://metacpan.org/pod/Text::Diff) is installed, a summary of differences between archived and current conditions will be written to a file that looks something like: `repro-archive/rdiff-sample.pl-YYYYMMDD.HHMMSS.vs.YYYYMMDD.HHMMSS`

After the warnings have been displayed, there is a prompt for whether to continue reproducing the archived analysis. If the user chooses to continue, all warnings and the path to the difference summary will be logged in the new archive.

If the current script name does not match the archived script name, the reproduced analysis will immediately fail (with instructions on how to proceed).
