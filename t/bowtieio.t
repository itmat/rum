#!perl
# -*- cperl -*-

use Test::More tests => 17;
use lib "lib";

use strict;
use warnings;
use autodie;

use RUM::BowtieIO;

my $data = <<EOF;
seq.591b\t-\t2\t3626971\tAACCTTCTTCTTGCTTCTTAAAGCTTTCATGGTGTATCCAAAGTCCATATGAGTCTTTGGCTTTGTGTCTTCTAA
seq.591b\t-\t4\t3952969\tAACCTTCTTCTTGCTTCTTAAAGCTTTCATGGTGTATCCAAAGTCCATATGAGTCTTTGGCTTTGTGTCTTCTAA
seq.591a\t-\t4\t3952969\tAACCTTCTTCTTGCTTCTTAAAGCTTTCATGGTGTATCCAAAGTCCATATGAGTCTTTGGCTTTGTGTCTTCTAA
EOF

open my $in, "<", \$data;

my $alns = RUM::BowtieIO->new(-fh => $in);
my $first = $alns->next_aln;
ok $first, "Got first alignment";
my $second = $alns->next_aln;
ok $second, "Got second alignment";
my $third = $alns->next_aln;
ok $third, "Got third alignment";
ok ! $alns->next_aln, "No more alignments";

is $first->strand, '-', "strand";

is $first->readid, "seq.591b", "read id";
is $first->chromosome, 2, "chromosome";

is_deeply $first->loc, 3626971, "loc";


is $first->seq, 'AACCTTCTTCTTGCTTCTTAAAGCTTTCATGGTGTATCCAAAGTCCATATGAGTCTTTGGCTTTGTGTCTTCTAA', "seq";
ok $first->is_reverse, "reverse";
ok $second->is_reverse, "reverse";
ok ! $third->is_reverse, "forward";

ok $first->is_same_read($second), "same read";
ok ! $third->is_same_read($second), "not same read";

ok ! $first->is_mate($second), "not mate";
ok $first->is_mate($third), "mate";

open my $out, ">", \(my $written);

$alns = RUM::BowtieIO->new(-fh => $out);

$alns->write_aln($first);
$alns->write_aln($second);
$alns->write_aln($third);
close $out;

is $written, $data, "write_aln";
