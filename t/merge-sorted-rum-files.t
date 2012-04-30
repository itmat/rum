#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::TestUtils;

use_ok "RUM::Script::MergeSortedRumFiles";

my @names;
my @fhs;

for (1 .. 4) {
    my $out = temp_filename();
    push @fhs, $out;
    push @names, $out->filename;
}

open my $in, "<", "$SHARED_INPUT_DIR/RUM_NU.sorted.1";
while (<$in>) {
    my $i = int(rand(@fhs));
    my $out = $fhs[$i];
    print $out $_;
}

for my $fh (@fhs) {
    close $fh;
}

my $out = temp_filename();

{
    @ARGV = ("-o", $out->filename, @names, "-q");
    RUM::Script::MergeSortedRumFiles->main();
    is_sorted_by_location($out);
}


