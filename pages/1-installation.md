---
layout: page
title: Installation
permalink: /installation/
---

### CPAN

Log::Reproducible can be installed using your favorite CPAN tool.

My favorite CPAN tool is `cpanm`, so I install Log::Reproducible with:

```sh
cpanm Log::Reproducible
```

If you want to install `cpanm`, you can do so by running the following (with `sudo`, when necessary):

```sh
curl -L http://cpanmin.us | perl - App::cpanminus
```

or 

```sh
wget -O - http://cpanmin.us | perl - App::cpanminus
```

### GitHub

#### Download

Get Log::Reproducible using one of two methods:

- Create a local clone the git repository on your computer:
    - `git clone https://github.com/mfcovington/Log-Reproducible.git`
- Download and extract the any version of Log::Reproducible as a `zip` or `tar.gz` archive from [GitHub](https://github.com/mfcovington/Log-Reproducible/releases).

#### Build and Install

On OS X, Linux, etc., use `autobuild.sh` or:

```sh
perl Build.pl
./Build
./Build test
./Build install
```

On Windows, use `autobuild.bat` or:

```sh
perl Build.pl
Build
Build test
Build install
```

