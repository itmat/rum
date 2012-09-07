#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Test::More tests => 4;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script::ParseBlatOut;
use RUM::TestUtils;
use File::Copy qw(cp);

SKIP: {
    skip "Don't have arabidopsis index", 4 if ! -e $GENOME_FA;

    my @tests = (
        {
            reads => "$INPUT_DIR/R.2",
            blat_results => "$INPUT_DIR/R.blat.2",
            mdust_results => "$INPUT_DIR/R.mdust.2",
            genome   => $GENOME_FA,
            unique => temp_filename(TEMPLATE => "unique.XXXXXX"),
            non_unique => temp_filename(TEMPLATE => "non-unique.XXXXXX"),
            expected_unique => "$EXPECTED_DIR/BlatUnique.2",
            expected_nu => "$EXPECTED_DIR/BlatNU.2",
            last_id => 1,
        },
        
        {
            reads => "$INPUT_DIR/R.1",
            genome   => $GENOME_FA,
            blat_results => "$INPUT_DIR/R.1.blat",
            mdust_results => "$INPUT_DIR/R.mdust.1",
            unique => temp_filename(TEMPLATE => "unique.XXXXXX"),
            non_unique => temp_filename(TEMPLATE => "non-unique.XXXXXX"),
            expected_unique => "$EXPECTED_DIR/BlatUnique.1",
            expected_nu => "$EXPECTED_DIR/BlatNU.1",
            last_id => 999
        },
    );
    
    
    # With sorted input
    
    for my $test (@tests) {
        
        open my $blathits,       '<', $test->{blat_results};
        open my $reads_in,       '<', $test->{reads};
        open my $mdust_in,       '<', $test->{mdust_results};
        open my $genome_in,      '<', $test->{genome};
        open my $unique_out,     '>', $test->{unique};
        open my $non_unique_out, '>', $test->{non_unique};
        
        my $script = RUM::Script::ParseBlatOut->new;
        $script->{max_distance_between_paired_reads} = 500000;
        $script->{num_insertions_allowed} = 1;
        $script->{match_length_cutoff} = 0;
        $script->{first_seq_num} = 1;
        $script->{last_seq_num} = $test->{last_id};
        $script->{num_blocks_allowed} = 1000;
        $script->{paired_end} = 'true';
        $script->parse_output(
            $blathits, $reads_in, $mdust_in, $unique_out, $non_unique_out);
        
        for my $fh ($reads_in, $mdust_in, $genome_in, 
                    $unique_out, $non_unique_out, $blathits) {
            close $fh;
        }
        
        my @expected_unique = `cat $test->{expected_unique}`;
        my @got_unique      = `cat $test->{unique}`;
        is_deeply \@got_unique, \@expected_unique, 'Unique';
        
        my @expected_nu = `sort $test->{expected_nu}`;
        my @got_nu      = `sort $test->{non_unique}`;
        is_deeply \@got_nu, \@expected_nu, 'Non-unique';
        
    }
}
