#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;
use FindBin qw($Bin);
use File::Copy;
use lib "$Bin/../lib";
use RUM::Script::MergeBowtieAndBlat;
use RUM::TestUtils;

my $blat_non_unique_tmp = temp_filename(
    TEMPLATE => "blat-non-unique-in.XXXXXX")->filename;

my $bowtie_unique     = "$INPUT_DIR/BowtieUnique.1";
my $blat_unique       = "$INPUT_DIR/BlatUnique.1";
my $bowtie_non_unique = "$INPUT_DIR/BowtieNU.1";
my $blat_non_unique   = "$INPUT_DIR/BlatNU.1";

my $merged_unique     = temp_filename(TEMPLATE => "unique.XXXXXX")->filename;

my $merged_non_unique = temp_filename(TEMPLATE => "non-unique.XXXXXX")->filename;

copy $blat_non_unique, $blat_non_unique_tmp;

for my $type (qw(paired)) {
    @ARGV = ("--bowtie-unique-in", $bowtie_unique,
             "--blat-unique-in",   $blat_unique, 
             "--bowtie-non-unique-in", $bowtie_non_unique, 
             "--blat-non-unique-in", $blat_non_unique_tmp,
             "--unique-out", $merged_unique,
             "--non-unique-out", $merged_non_unique, 
             "--$type",
             "--read-length", 75,
             "--quiet");
    RUM::Script::MergeBowtieAndBlat->main();
    no_diffs($merged_unique,     "$EXPECTED_DIR/RUM_Unique_temp.1");
    no_diffs($merged_non_unique, "$EXPECTED_DIR/RUM_NU_temp.1");
}

