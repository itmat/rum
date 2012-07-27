#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 8;
use Test::Exception;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script::MakeUnmappedFile;
use RUM::TestUtils;

my $reads      = "$INPUT_DIR/reads.fa.1";
my $unique     = "$INPUT_DIR/BowtieUnique.1";
my $non_unique = "$INPUT_DIR/BowtieNU.1";
my $unmapped   = temp_filename("unmapped.XXXXXX");
my $unmapped_single   = temp_filename("unmapped-single.XXXXXX");

sub make_unmapped_file {
    @ARGV = @_;
    RUM::Script::MakeUnmappedFile->main();    
}


make_unmapped_file(
    "--reads-in", $reads, 
    "--unique-in", $unique, 
    "--non-unique-in", $non_unique, 
    "--output", $unmapped,
    "--paired",
    "-q");

no_diffs($unmapped, "$EXPECTED_DIR/R.1");

make_unmapped_file(
    "--reads-in", "$INPUT_DIR/reads-single.fa",
    "--unique-in", "$INPUT_DIR/BowtieUnique-single",
    "--non-unique-in", "$INPUT_DIR/BowtieNU-single",
    "--output", $unmapped_single,
    "--single",
    "-q");

no_diffs($unmapped_single, "$EXPECTED_DIR/R-single");

throws_ok {
    make_unmapped_file(
        "--unique-in", "$INPUT_DIR/BowtieUnique-single",
        "--non-unique-in", "$INPUT_DIR/BowtieNU-single",
        "--output", $unmapped_single,
        "--single",
        "-q");
} qr/--reads/, "need reads file";


throws_ok {
    make_unmapped_file(
        "--reads-in", "$INPUT_DIR/reads-single.fa",
        "--non-unique-in", "$INPUT_DIR/BowtieNU-single",
        "--output", $unmapped_single,
        "--single",
        "-q");
} qr/--unique-in/, "need unique  file";

throws_ok {
    make_unmapped_file(
        "--reads-in", "$INPUT_DIR/reads-single.fa",
        "--unique-in", "$INPUT_DIR/BowtieUnique-single",
        "--output", $unmapped_single,
        "--single",
        "-q");
} qr/--non-unique-in/, "need non-unique file";

throws_ok {
    make_unmapped_file(
        "--reads-in", "$INPUT_DIR/reads-single.fa",
        "--unique-in", "$INPUT_DIR/BowtieUnique-single",
        "--non-unique-in", "$INPUT_DIR/BowtieNU-single",
        "--single",
        "-q");
} qr/--output/, "need output file";


throws_ok {
    make_unmapped_file(
        "--reads-in", "$INPUT_DIR/reads-single.fa",
        "--unique-in", "$INPUT_DIR/BowtieUnique-single",
        "--non-unique-in", "$INPUT_DIR/BowtieNU-single",
        "--output", $unmapped_single,
        "-q");
} qr/--single/, "need --single or --paired";

throws_ok {
    make_unmapped_file(
        "--reads-in", "$INPUT_DIR/reads-single.fa",
        "--unique-in", "$INPUT_DIR/BowtieUnique-single",
        "--non-unique-in", "$INPUT_DIR/BowtieNU-single",
        "--output", $unmapped_single,
        "--single", "--paired",
        "-q");
} qr/--single/, "need one of --single or --paired";
