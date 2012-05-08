Acquiring RUM
-------------

We recommend that you download the latest release from
https://github.com/PGFI/rum/downloads.

If you need the latest development version, you can fork the
repository from https://github.com/PGFI/rum.

Third-Party Libraries
---------------------

### Autodie

You will now need the `autodie` Perl module. If you are using perl >=
5.10, this should already be installed. If not, you may neet to
install it. You should be able to install it very quickly by running:

```
cpan -i autodie
```

### Log::Log4perl

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
