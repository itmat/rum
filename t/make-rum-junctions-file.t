#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

use RUM::TestUtils;

our $annotations = $RUM::TestUtils::GENE_INFO;
our $genome = $RUM::TestUtils::GENOME_FA;

our $sam_in = "$INPUT_DIR/rum.sam";

my @tests = (

    # { name => "strand-specific-p",
    #   all_rum  => "$EXPECTED_DIR/junctions_ps_all.rum",
    #   all_bed  => "$EXPECTED_DIR/junctions_ps_all.bed",
    #   high_bed => "$EXPECTED_DIR/junctions_high-quality_ps.bed",
    #   options => ["-strand", "p"] },

    # { name => "strand-specific-m",
    #   all_rum  => "$EXPECTED_DIR/junctions_ms_all.rum",
    #   all_bed  => "$EXPECTED_DIR/junctions_ms_all.bed",
    #   high_bed => "$EXPECTED_DIR/junctions_high-quality_ms.bed",
    #   options => ["-strand", "m"] },

    { name => "not-strand-specific",
      all_rum  => "$EXPECTED_DIR/junctions_all_temp.rum",
      all_bed  => "$EXPECTED_DIR/junctions_all_temp.bed",
      high_bed => "$EXPECTED_DIR/junctions_high-quality_temp.bed",
      options => [] } 

);

plan tests => 1 + 3 * @tests;

use_ok "RUM::Script::MakeRumJunctionsFile";


for my $test (@tests) {

    my %test = %{ $test };

    my ($all_rum, $all_bed, $high_bed) = @test{qw(all_rum all_bed high_bed)};
    my $name = $test->{name};
    my $all_rum_out  = temp_filename(TEMPLATE => "$name-all-rum.XXXXXX");
    my $all_bed_out  = temp_filename(TEMPLATE => "$name-all-bed.XXXXXX");
    my $high_bed_out = temp_filename(TEMPLATE => "$name-high-bed.XXXXXX");

    @ARGV = (
        "--sam-in",        $sam_in,
        "--sam-out",       '/dev/null',
        "--genome",        $genome,
        "--genes",         $annotations,
        "--all-rum-out",   $all_rum_out,
        "--all-bed-out",   $all_bed_out,
        "--high-bed-out",  $high_bed_out,
        "-faok",
        "-q",
        @{ $test->{options} } );
    
  SKIP: {
     
        skip "Indexes are not installed", 3 unless -e $annotations;
   
        RUM::Script::MakeRumJunctionsFile->main();
        
        no_diffs($all_rum_out,  $all_rum,  "$all_rum $all_rum_out");
        no_diffs($all_bed_out,  $all_bed,  "$all_bed $all_bed_out");
        no_diffs($high_bed_out, $high_bed, "$high_bed $high_bed_out");
    }
}

