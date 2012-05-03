#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 11;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use_ok("RUM::Script::RumToQuantifications");
use RUM::TestUtils;

my $unique = "$SHARED_INPUT_DIR/RUM_Unique.sorted.1";
my $non_unique = "$SHARED_INPUT_DIR/RUM_NU.sorted.1";

my $genes = $RUM::TestUtils::GENE_INFO;

my @standard_args = ("--genes", $genes, "--unique", $unique, "--non-unique", $non_unique);

SKIP: {
    skip "Don't have arabidopsis index", 10 unless -e $genes;
    posonly_strand_ok();
    posonly_countsonly_ok();
    posonly_ok();
}

sub run_with_extra_args {
    my @args = @_;
    my $out  = temp_filename(TEMPLATE => "quant.XXXXXX", UNLINK => 0);
    @ARGV = (@standard_args, "-o", $out, @args);
#    system("perl $Bin/../bin/rum2quantifications.pl @ARGV");
    RUM::Script::RumToQuantifications->main();
    return $out;
}

sub posonly_ok {
    my $out = run_with_extra_args("-posonly");
    open my $in, "<", $out or die "Can't open $out for reading: $!";
    
    my $num_zero_intensity = 0;
    my $count;
    while (defined(local $_ = <$in>)) {
        next unless /^transcript/;
        $count++;
        my (undef, undef, $min, $max) = split /\t/;
        $max or $num_zero_intensity++;
    }
    
    ok($count > 0, "Found some transcripts");
    is($num_zero_intensity, 0, "All transcripts have intensity > 0");
}


sub posonly_countsonly_ok {
    my $out = run_with_extra_args("-posonly", "-countsonly");
    open my $in, "<", $out or die "Can't open $out for reading: $!";
    
    my ($transcripts, $exons, $introns, $other);
    while (defined(local $_ = <$in>)) {
        if    (/^transcript/) { $transcripts++ }
        elsif (/^exon/) { $exons++ }
        elsif (/^intron/) { $introns++ }
        else { $other++ }
    }

    ok($transcripts, "Found some transcripts");
    ok($exons, "Found some exons");
    ok($introns, "Found some introns");
    ok($other == 1, "Found one other line");
}

sub get_strand_counts {
    my $filename = shift;
    open my $in, "<", $filename or die "Can't open $filename for reading: $!";
    my %counts = ('+' => 0, '-' => 0);
    while (defined(local $_ = <$in>)) {
        if (/.*\(ensembl\)\s+(\+|-)/) {
            $counts{$1}++;
        }
    }
    return \%counts;
}

sub posonly_strand_ok {
    my $neg = run_with_extra_args("-posonly", "-strand", "m");
    my $pos = run_with_extra_args("-posonly", "-strand", "p");

    my $pos_counts = get_strand_counts($pos);
    my $neg_counts = get_strand_counts($neg);

    ok($pos_counts->{'+'}, "Running with -strand p outputs + strand");
    is($pos_counts->{'-'}, 0, "Running with -strand p only outputs + strand");
    ok($neg_counts->{'-'}, "Running with -strand m outputs - strand");
    is($neg_counts->{'+'}, 0, "Running with -strand m only outputs - strand");

}
