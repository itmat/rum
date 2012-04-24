#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 1;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script::MakeUnmappedFile;
use RUM::TestUtils;

my $reads      = "$INPUT_DIR/reads.fa.1";
my $unique     = "$INPUT_DIR/BowtieUnique.1";
my $non_unique = "$INPUT_DIR/BowtieNU.1";
my $unmapped   = temp_filename("unmapped.XXXXXX");

@ARGV = (
    "--reads-in", $reads, 
    "--unique-in", $unique, 
    "--non-unique-in", $non_unique, 
    "--output", $unmapped,
    "--paired",
    "-q");

RUM::Script::MakeUnmappedFile->main();
no_diffs($unmapped, "$EXPECTED_DIR/R.1");


