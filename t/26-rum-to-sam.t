#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 9;
use FindBin qw($Bin);
use File::Copy;
use lib "$Bin/../lib";
use RUM::Script::LimitNU;
use RUM::TestUtils;

my $unique_in     = "$INPUT_DIR/RUM_Unique.1";
my $non_unique_in = "$INPUT_DIR/RUM_NU.1";
my $reads_in      = "$INPUT_DIR/reads.fa.1";
my $quals_in      = "$INPUT_DIR/quals.fa.1";

my $sam_out = temp_filename(TEMPLATE => "sam.XXXXXX");

my %configs = (
    u_nu_quals => [$unique_in, $non_unique_in, $reads_in, $quals_in],
    nu_quals   => ["none", $non_unique_in, $reads_in, $quals_in],
    u_quals    => [$unique_in, "none", $reads_in, $quals_in],
    u_nu       => [$unique_in, $non_unique_in, $reads_in, "none"],
    nu         => ["none", $non_unique_in, $reads_in, "none"],
    u          => [$unique_in, "none", $reads_in, "none"],
);


while (my ($name, $args) = each %configs) {
    @ARGV = @$args;
    my $out = temp_filename(TEMPLATE => "$name-XXXXXX");
    system("$Bin/../bin/rum2sam.pl @ARGV $out");
    no_diffs($out, "$EXPECTED_DIR/$name.sam", $name);
}

for my $suppress (1, 2, 3) {
    my $name = "suppress$suppress";
    my $out = temp_filename(TEMPLATE => "$name-XXXXXX");
    system("$Bin/../bin/rum2sam.pl @ARGV $out -suppress$suppress");
    no_diffs($out, "$EXPECTED_DIR/$name.sam", $name);
}
