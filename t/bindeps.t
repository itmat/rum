#!perl

use strict;
use warnings;

use lib "lib";
use RUM::BinDeps;

use Test::More tests => 7;

my $deps = RUM::BinDeps->new;

is($deps->dir,    "lib/RUM",        "bin dir");
is($deps->bowtie, "lib/RUM/bowtie", "bowtie path");
is($deps->blat,   "lib/RUM/blat",   "blat path");
is($deps->mdust,  "lib/RUM/mdust",  "mdust path");

my $dir = $deps->_download_to_tmp_dir;

for (qw(bowtie blat mdust)) {
    ok -e "$dir/$_", "downloaded $_";
}
