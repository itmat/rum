#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;
use FindBin qw($Bin);
use lib "$Bin/../lib";
#use RUM::Script::ParseBlatOut;
use RUM::TestUtils;



my $bowtie_unique     = "$INPUT_DIR/BowtieUnique.1";
my $blat_unique       = "$INPUT_DIR/BlatUnique.1";
my $bowtie_non_unique = "$INPUT_DIR/BowtieNU.1";
my $blat_non_unique   = "$INPUT_DIR/BlatNU.1";

my $merged_unique     = temp_filename(TEMPLATE => "unique.XXXXXX");
my $merged_non_unique = temp_filename(TEMPLATE => "non-unique.XXXXXX");


for my $type (qw(paired)) {
    @ARGV = ($bowtie_unique, $blat_unique, $bowtie_non_unique, $blat_non_unique,
             $merged_unique, $merged_non_unique, $type, "-readlength", 75);
    #RUM::Script::ParseBlatOut->main();
    system("perl $Bin/../bin/merge_Bowtie_and_Blat.pl @ARGV");
    no_diffs($merged_unique,     "$EXPECTED_DIR/RUM_Unique_temp.1");
    no_diffs($merged_non_unique, "$EXPECTED_DIR/RUM_NU_temp.1");
}

