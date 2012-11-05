#!perl
# -*- cperl -*-

use Test::More tests => 36;
use lib "lib";
use File::Temp;
use strict;
use warnings;

BEGIN { 
  use_ok('RUM::Common', qw(getave format_large_int reversesignal 
                           spansTotalLength addJunctionsToSeq Roman arabic
                           isroman roman num_digits is_fasta is_fastq));
}

is(getave("10184-10303"), "10243.5");
is(getave("32004713-32004734",
          "32005767-32005815",
          "32016413-32016461"),
   "32004723.5");

is(format_large_int(1234567890), "1,234,567,890",
   "format large int");


# reversesignal
is(reversesignal("AC"), "GT", "Reverse signal 1");
is(reversesignal("TG"), "CA", "Reverse signal 2");

#spansTotalLength

is(spansTotalLength("1-5, 10-12, 20-30"), 19,
   "spansTotalLength");

is(spansTotalLength("-6"), 7, "spansTotalLength with bad span");
is(spansTotalLength("6-"), -5, "spansTotalLength with bad span");
is(spansTotalLength("-"), 1, "spansTotalLength with bad span");
is(spansTotalLength(""), 0, "spansTotalLength with no span");

is(addJunctionsToSeq("C", "-0"), "C", "addJunctionsToSeq with bad input");
is(addJunctionsToSeq("AAACCCGGGTTT", "2-4, 6-9"), "AAA:CCCG", "addJunctionsToSeq with bad input");
is(addJunctionsToSeq("ATTC+CCG+GGTTTTTTTT", "3-8"), "ATTC+CCG+GG", "addJunctionsToSeq two + signs");
is(addJunctionsToSeq("ATTC+CCG+GGTTTTTTTT", "3-80"), "ATTC+CCG+GGTTTTTTTT", "addJunctionsToSeq with span that stretches past seq");
is(addJunctionsToSeq("ATTC+CCGGGTTTTTTTT", "3-8"), "ATTC+CCGGGTTTTTTTT", "addJunctionsToSeq with no terminating +");

my @arabic = (1..20);
my @romans = qw(I II III IV V VI VII VIII IX X 
                XI XII XIII XIV XV XVI XVII XVIII XIX XX);
is_deeply([ map { Roman($_) } @arabic], \@romans, "Roman");
is_deeply([ map { arabic($_) } @romans], \@arabic, "arabic");
is(length(grep { isroman($_) } @romans), length(@romans), "isroman");
is(roman(14), "xiv", "roman");
is(Roman(0), undef, "Roman with 0 as input");
is(Roman(100000), undef, "Roman with large input");
is(arabic(""), undef, "arabic with empty input");
is(isroman(""), "", "isroman with empty input");
is(num_digits(0), 1);
is(num_digits(1), 1);
is(num_digits(9), 1);
is(num_digits(10), 2);
is(num_digits(99), 2);
is(num_digits(100), 3);

my @fasta_inputs = (
    ">foo\nACTG\n>bar\nGTCA\n",
    ">foo\nACTG\nGTCA\n>bar\nGGGG\nTTTT\n"
);

my @fastq_inputs = (
    "\@foo\nAAAA\n+foo\naojh\n\@bar\nGGGG\n+bar\n5361\n",
);

for my $fasta (@fasta_inputs) {
    my $tmp = File::Temp->new;
    print $tmp $fasta;
    close $tmp;
    ok(is_fasta($tmp),  "Fasta input is fasta:\n$fasta");
    ok(!is_fastq($tmp), "Fasta input is not fastq:\n$fasta");
}


for my $fastq (@fastq_inputs) {
    my $tmp = File::Temp->new;
    print $tmp $fastq;
    close $tmp;
    ok(is_fastq($tmp),  "Fastq input is fastq:\n$fastq");
    ok(!is_fasta($tmp), "Fastq input is not fasta:\n$fastq");
}
