#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;
use FindBin qw($Bin);
use lib "$Bin/../../lib";
use RUM::Script::ParseBlatOut;
use RUM::TestUtils;
use File::Copy qw(cp);

my @tests = (
    {
        reads => "$INPUT_DIR/R.2",
        blat_results => "$INPUT_DIR/R.blat.2",
        mdust_results => "$INPUT_DIR/R.mdust.2",
        unique => 'bad_file', #temp_filename(TEMPLATE => "unique.XXXXXX"),
        non_unique => temp_filename(TEMPLATE => "non-unique.XXXXXX"),
        expected_unique => "$EXPECTED_DIR/BlatUnique.2",
        expected_nu => "$EXPECTED_DIR/BlatNU.2",
    },

    {
        reads => "$INPUT_DIR/R.1",
        blat_results => "$INPUT_DIR/R.1.blat",
        mdust_results => "$INPUT_DIR/R.mdust.1",
        unique => temp_filename(TEMPLATE => "unique.XXXXXX"),
        non_unique => temp_filename(TEMPLATE => "non-unique.XXXXXX"),
        expected_unique => "$EXPECTED_DIR/BlatUnique.1",
        expected_nu => "$EXPECTED_DIR/BlatNU.1",
    },
);


# With sorted input

for my $test (@tests) {

    @ARGV = (
        "--reads-in", $test->{reads},
        "--blat-in", $test->{blat_results},
        "--mdust-in", $test->{mdust_results},
        "--unique-out", $test->{unique},
        "--non-unique-out", $test->{non_unique});
    RUM::Script::ParseBlatOut->main();
    no_diffs($test->{unique}, $test->{expected_unique}, "Unique");
    my @expected_nu = `sort $test->{expected_nu}`;
    my @got_nu      = `sort $test->{non_unique}`;
    is_deeply \@got_nu, \@expected_nu, 'Non-unique';
    
}

__END__

# With unsorted input

@ARGV = (
   "--reads-in", $reads,
   "--blat-in", "$blat_results.unsorted",
   "--mdust-in", $mdust_results,
   "--unique-out", $unique,
   "--non-unique-out", $non_unique);
RUM::Script::ParseBlatOut->main();

no_diffs($unique, "$EXPECTED_DIR/BlatUnique.1", "Unique unsorted");
cp $unique, "sorted-u";
cp $non_unique, "sorted-nu";

my @expected_reads = `cut -f 1 $EXPECTED_DIR/BlatNU.1`;
my @got_reads      = `cut -f 1 $non_unique`;

is_deeply(\@got_reads, \@expected_reads, "Non-unique read ids");
