#!perl
# -*- cperl -*-

use Test::More tests => 9;
use lib "lib";

use strict;
use warnings;

BEGIN { 
  use_ok('RUM::FileIterator', qw(file_iterator pop_it))
}

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

# Test separating a and b reads
{
    open my $in, "<", \$data;
    my $it = file_iterator($in, separate => 1);
    my @rows;
    while (my $row = pop_it($it)) {
        push @rows, $row;
    }

    is(@rows, 14, "Got right number of rows");
    is_deeply( [map { $_->{seqnum} } @rows],
        [qw(12017 2933 2933 2821 4375 4375 11212 3384 3384
            10178 10178 12499 12499 11163)], "Got right sequence numbers");


    is_deeply( [map { $_->{start} } @rows],
               [qw(4482148 4485234 4485105 4762026 5140119 5152313           
                   7161082 7163391 7163244 8914350 8914495 8962483
                   8962622 9657925)], 
               "Got right start positions");

    is_deeply( [map { $_->{end} } @rows],
               [qw(4482256 4485353 4485224 4762236 5152281 5152432
                   7161320 7163510 7163363 8914469 8914614 8962602
                   8962741 9658044)], 
               "Got right end positions");

};

{
    open my $in, "<", \$data;
    my $it = file_iterator($in, separate => 0);
    my @rows;
    while (my $row = pop_it($it)) {
        push @rows, $row;
    }

    is(@rows, 9, "Got right number of rows without separating");
    is_deeply( [map { $_->{seqnum} } @rows],
        [qw(12017 2933 2821 4375 11212 3384 10178 12499 11163)],
               "Got right sequence numbers without separating");


    is_deeply( [map { $_->{start} } @rows],
               [qw(4482148 4485105 4762026 5140119 7161082
                   7163244 8914350 8962483 9657925)], 
               "Got right start positions without separating");

    is_deeply( [map { $_->{end} } @rows],
               [qw(4482256 4485353 4762236 5152432 7161320
                   7163510 8914614 8962741 9658044)],
               "Got right end positions without separating");

};

