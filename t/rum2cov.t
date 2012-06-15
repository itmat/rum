#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::TestUtils;

use RUM::Script::RumToCov;

sub rum2cov {
    @ARGV = @_;
    RUM::Script::RumToCov->main;
}

{
    my $nu = "$INPUT_DIR/RUM_NU";
    
    my $got_nu_cov   = temp_filename(TEMPLATE => "nu.cov.XXXXXX");
    my $got_nu_stats = temp_filename(TEMPLATE => "nu.stats.XXXXXX");
    
    my $exp_nu_cov   = "$EXPECTED_DIR/nu.cov";
    my $exp_nu_stats = "$EXPECTED_DIR/nu.stats";
    
    rum2cov(
        "--output", $got_nu_cov,
        "--stats",  $got_nu_stats,
        $nu);
    
    no_diffs($got_nu_cov, $exp_nu_cov, "NU cov", "-I 'track type=bedGraph'");
    
    open my $stats, "<", $got_nu_stats;
    my $line = <$stats>;
    like $line, qr/footprint for .* : 68957/, "NU stats";
}

{
    my $in = "$INPUT_DIR/RUM_Unique";
    
    my $got_cov   = temp_filename(TEMPLATE => "u.cov.XXXXXX");
    my $got_stats = temp_filename(TEMPLATE => "u.stats.XXXXXX");
    
    my $exp_cov   = "$EXPECTED_DIR/u.cov";
    my $exp_stats = "$EXPECTED_DIR/u.stats";
    
    rum2cov(
        "--output", $got_cov,
        "--stats",  $got_stats,
        $in);
    
    no_diffs($got_cov, $exp_cov, "Unique cov", "-I 'track type=bedGraph'");
    
    open my $stats, "<", $got_stats;
    my $line = <$stats>;
    like $line, qr/footprint for .* : 72603/, "Unique stats";
}
