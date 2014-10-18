---
layout:   post
title:    Reproducing an Archived Analysis
to_prev: contents
to_next: inconsistencies
---

To reproduce an archived run, all you need to do is run the script followed by `--reproduce` and the path to the archive file. For example:

```sh
perl sample.pl --reproduce rlog-sample.pl-YYYYMMDD.HHMMSS
```

This results in:

1. The script being executed with the command line options and arguments used in the original archived run
2. The creation of a new archive file identical to the older one, except with:
    - an updated date and time
    - the addition of /path/to/the/old/archive
3. The reproduction information being logged in the original archive
