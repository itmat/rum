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

We recommend that you download the latest release from
https://github.com/PGFI/rum/downloads. If you need the latest
development version, you can fork the repository from
https://github.com/PGFI/rum.

The new recommended way to install RUM is to use the standard Perl
module installation process:

```sh
perl Makefile.PL
make
make test # (optional, takes a couple minutes)
make install # (may need sudo)
```

You should also be able to install RUM in a non-standard location by
passing a `INSTALL_BASE=/some/path` option to the `perl Makefile.PL
step`. RUM should automatically find all of its perl modules if you
install it in this manner.

Installing Indexes
------------------

Then you should use the `rum_indexes` program to install one or more
indexes. By default it will install indexes in the location where you
installed RUM itself, but you can use the `--prefix` option to tell it
to install indexes somewhere else:

```sh
# Install them where you installed rum
rum_indexes

# Install them in ~/rum-indexes
rum_indexes --prefix ~/rum-indexes
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