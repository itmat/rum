#!perl
# -*- cperl -*-

use Test::More tests => 22;
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

my $data = <<INFILE;
seq.12017a	chr1	4482148-4482256	-	TGCGGCGGGCGAGCCCATCGCGCCGTA
seq.2933a	chr1	4485234-4485353	-	CATGCTGAGGTTTTCCTGTATTATTTC
seq.2933b	chr1	4485105-4485224	-	AAGGAAGGAAGGAAGGAAGGAAGGAAG
seq.2821	chr1	4762026-4762236	-	ATCGAAGCCATAGAAGCCAGTGTGATG
seq.4375a	chr1	5140119-5140142, 5152186-5152281	+	GCA
seq.4375b	chr1	5152313-5152432	+	TAAAAGCAAATAGTCTTTAATTTAATG
seq.11212	chr1	7161082-7161320	+	TTCACTTTTTGCTTAATACTACATTCT
seq.3384a	chr1	7163391-7163510	-	TTCGATTCTATATTAAGTAGAGTTGAA
seq.3384b	chr1	7163244-7163363	-	TTTTAAACATATGTTTACTCTTCCAAG
seq.10178a	chr1	8914350-8914469	+	CTATCGCAGGCTAAACCTGAGGTCAGC
seq.10178b	chr1	8914495-8914614	+	GGAAACACTGACTGTGGGGTTTGTCAT
seq.12499a	chr1	8962483-8962602	+	CTTTTAGGTGTGTGGTCAAGCTGCTAC
seq.12499b	chr1	8962622-8962741	+	AACTTTAAAAAGTCTGTAATTTCTTTC
seq.11163a	chr1	9657925-9658044	+	AAAAATTATGTTTTAGAATATGTAACG
INFILE

{
    open my $in, "<", \$data;
    my $it = RUM::RUMIO->new(-fh => $in)->aln_iterator;
    my @rows;
    while (my $row = $it->next_val) {
        push @rows, $row;
    }
    
    is(@rows, 14, "Got right number of rows");
    is_deeply( [map { $_->readid =~ /(\d+)/ && $1 } @rows],
               [qw(12017 2933 2933 2821 4375 4375 11212 3384 3384
                   10178 10178 12499 12499 11163)], 
               "Got right sequence numbers");
    
    is_deeply( [map { $_->start } @rows],
               [qw(4482148 4485234 4485105 4762026 5140119 5152313           
                   7161082 7163391 7163244 8914350 8914495 8962483
                   8962622 9657925)], 
               "Got right start positions");

    is_deeply( [map { $_->end } @rows],
               [qw(4482256 4485353 4485224 4762236 5152281 5152432
                   7161320 7163510 7163363 8914469 8914614 8962602
                   8962741 9658044)], 
               "Got right end positions");

};

{
    open my $in, "<", \$data;
    my $it = RUM::RUMIO->new(-fh => $in)->aln_iterator->group_by(\&RUM::Identifiable::is_mate);
    my @rows;
    while (my $row = $it->next_val) {
        push @rows, $row;
    }

    is(@rows, 9, "Got right number of rows without separating");
    is_deeply( [map { $_->[0]->readid =~ /(\d+)/ and $1 } @rows],
        [qw(12017 2933 2821 4375 11212 3384 10178 12499 11163)],
               "Got right sequence numbers without separating");

    my @ranges = map { [ RUM::RUMIO->pair_range(@$_) ] } @rows;
    
    my @starts = map { $_->[0] } @ranges;
    my @ends   = map { $_->[1] } @ranges;

    is_deeply( \@starts,
               [qw(4482148 4485105 4762026 5140119 7161082
                   7163244 8914350 8962483 9657925)], 
               "Got right start positions without separating");

    is_deeply( \@ends,
               [qw(4482256 4485353 4762236 5152432 7161320
                   7163510 8914614 8962741 9658044)],
               "Got right end positions without separating");

};

