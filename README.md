Setting Up and Running RUM
==========================

 <img style="float:right" src="http://www.cbil.upenn.edu/RUM/RUMPC2_small2.gif" class="float: right"></img>

**RUM is an alignment, junction calling, and feature quantification
  pipeline specifically designed for Illumina RNA-Seq data.**

*RUM can also be used effectively for DNA sequencing (e.g. ChIP-Seq)
and microarray probe mapping.*

*RUM also has a strand specific mode.*

*RUM is highly configurable, however it does not require fussing over
options, the defaults generally give good results.*

Publication
-----------

[Comparative Analysis of RNA-Seq Alignment Algorithms and the RNA-Seq Unified Mapper (RUM)](http://www.ncbi.nlm.nih.gov/pubmed/21775302?dopt=Abstract) Gregory R. Grant, Michael H. Farkas, Angel Pizarro, Nicholas Lahens, Jonathan Schug, Brian Brunk, Christian J. Stoeckert Jr, John B. Hogenesch and Eric A. Pierce. 

Restrictions
------------

RUM is freely available to academics and non-profit
organizations. However since RUM uses BLAT, users from industry must
first obtain a licence for BLAT from the Kent Informatics Website.

System Requirements
-------------------

RUM should work anywhere you have most of the standard Unix
command-line tools, Perl, and can get the blat, bowtie and mdust
binaries to execute; however we haven't tested it on every
platform. Unless you have a relatively small genome, then you'll
probably need a 64 bit machine. For the human or mouse genome this
will definitely be necessary. For a lane of 20 million 100 bp reads,
paired-end, expect to use about 100-200 GB disk space.

### Third-Party Perl Modules

#### Autodie

You will now need the `autodie` Perl module. If you are using perl >=
5.10, this should already be installed. If not, you may need to
install it. You should be able to install it very quickly by running:

```
cpan -i autodie
```

#### Log::Log4perl

Log::Log4perl is recommended, but not required. You should be able to
install it by running:

```
cpan -i Log::Log4perl
```

If you have Log::Log4perl, you will be able to control logging output
by modifying the `conf/rum_logging.conf` file in the RUM
distribution. See http://mschilli.github.com/log4perl/ for more
information.

Installing RUM
--------------

You can download a specific version of RUM from the tags page on
github: https://github.com/PGFI/rum/tags. The latest production
release is always available at
https://github.com/PGFI/rum/archive/master.tar.gz. The latest
bleeding-edge development code (which may be unstable) is available
here: https://github.com/PGFI/rum/archive/develop.tar.gz.

You have a few different options for installing RUM, depending on
whether you want it in a system location, in an arbitrary user
directory, or in another location where you keep Perl modules.

### In a system directory

If you have root priviliges and want to install RUM in a system
location like `/usr/local`, you can now do so using the standard Perl
module installation process:

```sh
perl Makefile.PL
make
make install # (may need sudo)
```

### In a user directory

If you would rather install RUM in a user-owned directory, you can
simply untar RUM right in the directory where you to install it, and
then run `perl Makefile.PL`. For example, if you want to have rum
installed in `~/RUM-Pipeline-2.00_13`, assuming you have downloaded
`RUM-Pipeline-2.00_13.tar.gz` to your current directory, you can
simply do:

```
tar zxvf RUM-Pipeline-2.00_13.tar.gz
cd RUM-Pipeline-2.00_13
perl Makefile.PL
```

This will place all the rum executables in `RUM-Pipeline-2.00_11/bin`.
They will find the RUM libraries they need automatically. You may want
to add the `bin` directory to your path, so that you can run RUM
simply by typing `rum_runner`:

```sh
export PATH="${PATH}:${RUM_HOME}/bin"
rum_runner ...
```

If you don't add the RUM bin directory to your path, you will need to
specify the path to `rum_runner` when you run it. For example, if
you're in the root of the RUM installation, you can run:

```sh
bin/rum_runner ...
```

If you're in the bin directory, run:

```sh
./rum_runner ...
```


### In an alternate Perl module location

If you have an alternate location where you keep Perl modules, you
should be able to install RUM there by passing an
`INSTALL_BASE=/some/path` option to the `perl Makefile.PL step`. RUM
should automatically find all of its perl modules if you install it in
this manner. For example:

```sh
RUM_HOME=~/rum
perl Makefile.PL INSTALL_BASE=$RUM_HOME
make
make install
```

As in the previous option, you will either need to run `rum_runner`
using the full path, or add `$RUM_HOME/bin` to your `$PATH`.

Installing Indexes
------------------

Once you install the RUM code, you'll want to use the `rum_indexes`
program to install one or more indexes. By default it will install
indexes in the location where you installed RUM itself, but you can
use the `--prefix` option to tell it to install indexes somewhere
else:

```sh
# Install them where you installed rum
rum_indexes

# Install them in ~/rum-indexes
rum_indexes --prefix ~/rum-indexes
```

When you install an index, all the files for that organism will be
placed in a new directory named after the organism. You will need to
specify the index directory when you run RUM. For example, if you
installed the mm9 index by running `rum_indexes --prefix
~/rum-indexes`, in order to align some reads using that index, you
would run:

```
rum_runner align --index ~/rum-indexes/mm9 ...
```

Note that you will need a lot of available disk space in order to
install indexes.

At the moment the following indexes are available:

* _Homo sapiens_ (build hg19) (**human**)
* _Homo sapiens_ (build hg18) (**human**)
* _Mus musculus_ (build mm9) (**mouse**)
* _Danio rerio_ (build danRer7) (**zebrafish**)
* _Drosophila melanogaster_ (build dm3) (**fruit fly**)
* _Anopheles gambiae_ (build anoGam1) (**mosquito**)
* _Caenorhabditis elegans_ (build c36) (**nematode worm**)
* _Saccharomyces cerevisiae_ (build sacCer3) (**yeast**)
* _Rattus norvegicus_ (build m4) (**rat**)
* _Sus scrofa_ (build susScr2) (**pig**)
* _Canis lupus familiaris_ (build canFam2) (**dog**)
* _Pan troglodytes_ (build panTro2) (**chimpanzee**)
* _Pongo pygmaeus abelii_ (build ponAbe2) (**orangutan**)
* _Macaca mulatta_ (build rheMac2) (**rhesus monkey**)
* _Gallus gallus_ (build galGal3) (**chicken**)
* _Plasmodium falciparum_ (build 06-2010) (**malaria parasite**)
* _Arabidopsis thaliana_ (build TAIR10) (**arabadopsis**)

We will be expanding this list regularly. If you require a different
organism, instructions are given
[here](https://github.com/PGFI/rum/blob/master/doc/indexing.pod) to
build your own custom indexes. Or write us, we may be able to provide
it.

Running RUM
-----------

After you've installed RUM and one or more indexes, please run
`rum_runner help` to see usage information. Please also see the [main
user guide](http://www.cbil.upenn.edu/RUM/userguide.php) for an
explanation of the pipeline and the output files.

Frequently Asked Questions
--------------------------

### My job stopped prematurely without writing any error messages to the log files. What happened?

rum_runner will attempt to write a FATAL message to the error logs if
it encounters an error that it can't handle and needs to
exit. However, there are some conditions that cause rum_runner to exit
immediately, and the program won't log a message in that case. Running
out of memory is one example. So if you have a job that just appeared
to stop prematurely without leaving any trace of a reason in the log
file, it's likely that it ran out of memory.

### I started a RUM job and now my system is unresponsive. Why?

If you run a job on a single machine and split it up into multiple
chunks, it may be using too much memory or CPU time.

For a human genome, each chunk will use about 6 GB of ram, so in order
to run it in 10 chunks on a single machine, you'd need at least 60 GB
of ram free to be safe.

You probably don't want to use more chunks than you have cores in your
system. For example if you have a dual-core system, running a job with
10 chunks will likely create high contention for CPU resources, making
your system seem unresponsive.

So if RUM seems to put too much strain on your system, reducing the
number of chunks might help.

### How should I run rum_runner in the background?

If you're on a Sun Grid Engine cluster and you run rum with the
`--qsub` option, it will do a minimal amount of processing up front
and then submit a job to do most of the work. So with SGE you don't
need to run it in the background.


If you're running it locally, you can use `nohup rum_runner
... &`. It's also very convenient to run rum_runner from within a [GNU
screen](http://www.gnu.org/software/screen) session.