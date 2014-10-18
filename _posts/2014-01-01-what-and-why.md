---
layout:  post
title:   "What (and Why) is Log::Reproducible?"
to_prev:
to_next: archive
---
Log::Reproducible is a Perl 5 module to help improve reproducibility.

### Motivation
In science (and probably any other analytical field), reproducibility is critical. If an analysis cannot be faithfully reproduced, it was arguably a waste of time. Therefore, reproducible research is a very important goal that we should all be striving for.

Since I write lots of code and run lots of scripts, one way I improved reproducibility in my own research was by creating a tool that does all the work for me — a Perl module called Log::Reproducible.

<!-- Increase your reproducibility with the Perl module Log::Reproducible. -->

<!-- **TAGLINE:** Set it and forget it... *until you need it!* -->

### How Log::Reproducible increases reproducibility

- Provides [effortless and thorough record keeping]({{ site.baseurl}}{% post_url 2014-02-01-archive %}) of the conditions under which scripts are run
- Allows [easy replication]({{ site.baseurl}}{% post_url 2014-04-01-reproduce %}) of these conditions
- Detects and [reports inconsistencies](#inconsistencies-between-current-and-archived-conditions) between archived and replicated conditions.

