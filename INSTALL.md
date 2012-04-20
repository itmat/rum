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
passing a `PREFIX=/some/path` option to the `perl Makefile.PL step`,
but if you do that you'll need to modify your PERL5LIB so that perl
can find the RUM libraries. Installing it in a system location is
easiest.

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
