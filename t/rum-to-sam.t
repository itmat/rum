#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 10;
use FindBin qw($Bin);
use File::Copy;
use lib "$Bin/../lib";
use RUM::Script::RumToSam;
use RUM::TestUtils;

my $genome_fa     = $RUM::TestUtils::GENOME_FA;
my $unique_in     = "$SHARED_INPUT_DIR/RUM_Unique.1";
my $non_unique_in = "$SHARED_INPUT_DIR/RUM_NU.1";
my $reads_in      = "$INPUT_DIR/reads.fa.1";
my $quals_in      = "$INPUT_DIR/quals.fa.1";
my $name_map      = "$INPUT_DIR/name-map";
my %configs = (
    u_nu_quals => [$unique_in, $non_unique_in, $reads_in, $quals_in],
    nu_quals   => [undef,      $non_unique_in, $reads_in, $quals_in],
    u_quals    => [$unique_in, undef,          $reads_in, $quals_in],
    u_nu       => [$unique_in, $non_unique_in, $reads_in, undef],
    nu         => [undef,      $non_unique_in, $reads_in, undef],
    u          => [$unique_in, undef,          $reads_in, undef],
);


while (my ($name, $args) = each %configs) {
    my ($unique, $non_unique, $reads, $quals) = @$args;
    my $out = temp_filename(TEMPLATE => "$name-XXXXXX");

    @ARGV = ("--sam-out", $out);
    push @ARGV, "--quals-in", $quals if $quals;
    push @ARGV, "--reads-in", $reads if $reads;
    push @ARGV, "--non-unique", $non_unique if $non_unique;
    push @ARGV, "--unique", $unique if $unique;
    push @ARGV, "--genome", $genome_fa;
    RUM::Script::RumToSam->main();
    no_diffs($out, "$EXPECTED_DIR/$name.sam", $name, "-I '^\@'");
}

for my $suppress (1, 2, 3) {
    
    my $name = "suppress$suppress";
    my $out = temp_filename(TEMPLATE => "$name-XXXXXX");

    @ARGV = ("--unique", $unique_in, 
             "--non-unique", $non_unique_in,
             "--reads-in", $reads_in,
             "--sam-out", $out, 
             "--quals-in", $quals_in,
             "--suppress$suppress");

    RUM::Script::RumToSam->main();
    no_diffs($out, "$EXPECTED_DIR/$name.sam", $name, "-I '^\@'");
}

{
    my $name = "name-mapping";
    my $out = temp_filename(TEMPLATE => "$name-XXXXXX");
    @ARGV = ("--unique", $unique_in, 
             "--non-unique", $non_unique_in,
             "--reads-in", $reads_in,
             "--sam-out", $out, 
             "--quals-in", $quals_in,
             "--name-mapping", $name_map);
    RUM::Script::RumToSam->main();
    open my $in, "<", $out;
    my @lines = grep { /(second|third)-(a|b)/ } (<$in>);
    is(scalar(@lines), 4, "Name mapping");
}


{
    my $name = "empty inputs";
    my $u   = temp_filename(TEMPLATE => "$name-XXXXXX");
    my $nu  = temp_filename(TEMPLATE => "$name-XXXXXX");
    my $out = temp_filename(TEMPLATE => "$name-XXXXXX");
    @ARGV = ("--unique", $u, 
             "--non-unique", $nu,
             "--reads-in", $reads_in,
             "--sam-out", $out, 
             "--quals-in", $quals_in);
    RUM::Script::RumToSam->main();
}
