#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script::MergeGuAndTu;
use RUM::TestUtils;
use File::Temp;

my $gu  = "$INPUT_DIR/GU.1";
my $tu  = "$INPUT_DIR/TU.1";
my $gnu = "$INPUT_DIR/GNU.1";
my $tnu = "$INPUT_DIR/TNU.1";

for my $type (qw(paired single)) {
    my $bowtie_unique  = temp_filename(TEMPLATE=>"$type-bowtie-unique.XXXXXX");
    my $cnu = temp_filename(TEMPLATE => "$type-cnu.XXXXXX",
                        UNLINK => 0);
    @ARGV = ("--gu", $gu, 
             "--tu", $tu, 
             "--gnu", $gnu, 
             "--tnu", $tnu,
             "--bowtie-unique", $bowtie_unique, 
             "--cnu", $cnu, 
             "--$type");
    
    RUM::Script::MergeGuAndTu->main();
    no_diffs($bowtie_unique, "$EXPECTED_DIR/$type-bowtie-unique", 
         "$type bowtie unique");
    no_diffs($cnu, "$EXPECTED_DIR/$type-cnu", "$type cnu");
}

sub test_merge {
    my %options = @_;

    my $gu_in             = $options{gu_in};
    my $tu_in             = $options{tu_in};
    my $gnu_in            = $options{gu_in};
    my $tnu_in            = $options{tu_in};
    my $bowtie_unique_out = $options{bowtie_unique_out};
    my $cnu_out           = $options{cnu_out};
}
