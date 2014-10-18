---
layout:  post
title:   Customizing Command Line Options
to_prev: location
to_next: 
---
It is possible to customize the names of the command line options that Log::Reproducible uses. This is important if there is a conflict with the option names of your script. It can also help save time by decreasing the number of keystrokes required. To override one or more of the defaults ([`reprodir`]({{ site.url }}{{ site.baseurl }}/docs/location/), [`reproduce`]({{ site.url }}{{ site.baseurl }}/docs/reproduce/), and [`repronote`]({{ site.url }}{{ site.baseurl }}/docs/notes/)), pass a hash reference when calling Log::Reproducible from your script:

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

**Note 2:** Assigning a value to the `dir` key is only required if you want to [set a script-level archive directory]({{ site.url }}{{ site.baseurl }}/docs/location/).

**Note 3:** Since `--repronote` is probably used more regularly than the other options, perhaps the most useful customization is:

```perl
use Log::Reproducible { repronote => 'note' };
```
