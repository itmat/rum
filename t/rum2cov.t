#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::TestUtils;

sub rum2cov {
    @ARGV = @_;
    # TODO: RumToCov does not use strict, because there are two subs
    # (getStartEndandSpans_of_nextline and main) that depend on a lot
    # of global variables. If we call main() twice in a row, some of
    # the state from the first call is still present when the second
    # call starts. This is not an issue in practice, because main is
    # just called once from rum2cov.pl. But for testing, this means
    # that we can't just call main twice in a row. If we load RumToCov
    # with 'do', it will clear the symbol table, so all the globals
    # will be fresh each time. It would be best to refactor it and get
    # rid of all the globals, but I'm having trouble with that, and
    # this works well enough for now.
    do "RUM/Script/RumToCov.pm";
    no strict 'subs';
    RUM::Script::RumToCov->main;
}

if (1) {
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

if (1) {
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
    system("cat $got_cov > u_cov");
    open my $stats, "<", $got_stats;
    my $line = <$stats>;
    like $line, qr/footprint for .* : 72603/, "Unique stats";
}
