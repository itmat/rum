#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use RUM::TestUtils;
#use_ok "RUM::Script::GetInferredInternalExons";

our $annotations = "_testing/indexes/Arabidopsis_thaliana_TAIR10_ensembl_gene_info.txt";

our $genome = "_testing/indexes/Arabidopsis_thaliana_TAIR10_genome_one-line-seqs.fa";

our $unique = "$SHARED_INPUT_DIR/RUM_Unique.1";
our $non_unique = "$SHARED_INPUT_DIR/RUM_NU.1";

my @tests = (

    { name => "strand-specific: p",
      all_rum  => "$EXPECTED_DIR/junctions_ps_all.rum",
      all_bed  => "$EXPECTED_DIR/junctions_ps_all.bed",
      high_bed => "$EXPECTED_DIR/junctions_high-quality_ps.bed",
      options => ["-strand", "p"] },
    { name => "strand-specific: m",
      all_rum  => "$EXPECTED_DIR/junctions_ms_all.rum",
      all_bed  => "$EXPECTED_DIR/junctions_ms_all.bed",
      high_bed => "$EXPECTED_DIR/junctions_high-quality_ms.bed",
      options => ["-strand", "m"] },
    { name => "not strand-specific",
      all_rum  => "$EXPECTED_DIR/junctions_all_temp.rum",
      all_bed  => "$EXPECTED_DIR/junctions_all_temp.bed",
      high_bed => "$EXPECTED_DIR/junctions_high-quality_temp.bed",
      options => [] } );

plan tests => 1 + 3 * @tests;

for my $test (@tests) {

    my %test = %{ $test };

    my ($all_rum, $all_bed, $high_bed) = @test{qw(all_rum all_bed high_bed)};

    my $all_rum_out  = temp_filename("all-rum.XXXXXX");
    my $all_bed_out  = temp_filename("all-bed.XXXXXX");
    my $high_bed_out = temp_filename("high-bed.XXXXXX");

    my @cmd = ("perl", "$Bin/../bin/make_RUM_junctions_file.pl",
               $unique, $non_unique, $genome, $annotations,
               $all_rum_out, $all_bed_out, $high_bed_out,
               "-faok", @{ $test->{options} } );
    system(@cmd) == 0 or fail("@cmd");
    
    no_diffs($all_rum_out,  $all_rum,  "$test->{name}: all rum");
    no_diffs($all_bed_out,  $all_bed,  "$test->{name}: all bed");
    no_diffs($high_bed_out, $high_bed, "$test->{name}: high-quality bed");
}



