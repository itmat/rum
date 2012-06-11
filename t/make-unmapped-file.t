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
my $unmapped_single   = temp_filename("unmapped-single.XXXXXX");

@ARGV = (
    "--reads-in", $reads, 
    "--unique-in", $unique, 
    "--non-unique-in", $non_unique, 
    "--output", $unmapped,
    "--paired",
    "-q");

RUM::Script::MakeUnmappedFile->main();
no_diffs($unmapped, "$EXPECTED_DIR/R.1");

@ARGV = (
    "--reads-in", "$INPUT_DIR/reads-single.fa",
    "--unique-in", "$INPUT_DIR/BowtieUnique-single",
    "--non-unique-in", "$INPUT_DIR/BowtieNU-single",
    "--output", $unmapped_single,
    "--single",
    "-q");

RUM::Script::MakeUnmappedFile->main();
no_diffs($unmapped_single, "$EXPECTED_DIR/R-single");
