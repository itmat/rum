#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use RUM::TestUtils;
use_ok "RUM::Script::MakeRumJunctionsFile";

our $annotations = "_testing/indexes/Arabidopsis_thaliana_TAIR10_ensembl_gene_info.txt";

our $genome = "_testing/indexes/Arabidopsis_thaliana_TAIR10_genome_one-line-seqs.fa";

our $unique = "$SHARED_INPUT_DIR/RUM_Unique.1";
our $non_unique = "$SHARED_INPUT_DIR/RUM_NU.1";

my @tests = (

    { name => "strand-specific-p",
      all_rum  => "$EXPECTED_DIR/junctions_ps_all.rum",
      all_bed  => "$EXPECTED_DIR/junctions_ps_all.bed",
      high_bed => "$EXPECTED_DIR/junctions_high-quality_ps.bed",
      options => ["--strand", "p"] },

    { name => "strand-specific-m",
      all_rum  => "$EXPECTED_DIR/junctions_ms_all.rum",
      all_bed  => "$EXPECTED_DIR/junctions_ms_all.bed",
      high_bed => "$EXPECTED_DIR/junctions_high-quality_ms.bed",
      options => ["--strand", "m"] },

    { name => "not-strand-specific",
      all_rum  => "$EXPECTED_DIR/junctions_all_temp.rum",
      all_bed  => "$EXPECTED_DIR/junctions_all_temp.bed",
      high_bed => "$EXPECTED_DIR/junctions_high-quality_temp.bed",
      options => [] } );

plan tests => 1 + 3 * @tests;

for my $test (@tests) {
#    $test = $tests[2];
    my %test = %{ $test };

    my ($all_rum, $all_bed, $high_bed) = @test{qw(all_rum all_bed high_bed)};
    my $name = $test->{name};
    my $all_rum_out  = temp_filename(TEMPLATE => "$name-all-rum.XXXXXX",
                                 UNLINK => 0);
    my $all_bed_out  = temp_filename(TEMPLATE => "$name-all-bed.XXXXXX",
                                 UNLINK => 0);
    my $high_bed_out = temp_filename(TEMPLATE => "$name-high-bed.XXXXXX",
                                     UNLINK => 0);

    @ARGV = (
        "--unique-in", $unique,
        "--non-unique-in", $non_unique,
        "--genome", $genome,
        "--genes", $annotations,
        "--all-rum-out", $all_rum_out,
        "--all-bed-out", $all_bed_out,
        "--high-bed-out", $high_bed_out,
        "--faok",
        , @{ $test->{options} } );

    my @args = ("perl", "$Bin/../bin/make_RUM_junctions_file.pl", @ARGV);

    RUM::Script::MakeRumJunctionsFile->main();
    #system(@args);
    
    no_diffs($all_rum_out,  $all_rum,  "$all_rum $all_rum_out");
    no_diffs($all_bed_out,  $all_bed,  "$all_bed $all_bed_out");
    no_diffs($high_bed_out, $high_bed, "$high_bed $high_bed_out");
}



