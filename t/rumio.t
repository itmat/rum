#!perl
# -*- cperl -*-

use Test::More tests => 14;
use lib "lib";

use strict;
use warnings;
use autodie;

use RUM::RUMIO;

my $data = <<EOF;
seq.209b\t1\t15043461-15043535\t+\tGATCCCATCTACCTAGAGTATAACAATGAAGTTCTAATTGCAATCCCAACTCCTGTCCCAACTTAACTCTACCCT
seq.79a\t1\t15081867-15081872, 15082275-15082340\t+\tAGTGTT:TCCTTGTTAGAAGACACAAAGCCAAAGACTCATATGGACTTTGGCTACACCATGAAAGCTTNGAGA
EOF

open my $in, "<", \$data;

my $alns = RUM::RUMIO->new(-fh => $in);
my $first = $alns->next_aln;
ok $first, "Got first alignment";
my $second = $alns->next_aln;
ok $second, "Got second alignment";
ok ! $alns->next_aln, "No more alignments";

is $first->readid, "seq.209b", "read id";
is $second->readid, "seq.79a", "read id";

is $first->chromosome, 1, "chromosome";

is_deeply $first->locs, [[15043461, 15043535]], "locs";
is_deeply $second->locs, [[15081867, 15081872], [15082275, 15082340]], "locs";

is $first->strand, '+', "strand";

is $first->seq, 'GATCCCATCTACCTAGAGTATAACAATGAAGTTCTAATTGCAATCCCAACTCCTGTCCCAACTTAACTCTACCCT', "seq";
is $second->seq, 'AGTGTT:TCCTTGTTAGAAGACACAAAGCCAAAGACTCATATGGACTTTGGCTACACCATGAAAGCTTNGAGA', "seq";

open my $out, ">", \(my $written);

$alns = RUM::RUMIO->new(-fh => $out);

$alns->write_aln($first);
$alns->write_aln($second);

ok $first->is_reverse, "reverse";
ok ! $second->is_reverse, "forward";

close $out;

is $written, $data, "write_aln";
