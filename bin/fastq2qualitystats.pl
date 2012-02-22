# Written by Elisabetta Manduchi, based on a script by Greg Grant
# University of Pennslyvania, 2010

use strict;

if (@ARGV < 1) {
  die "
Usage: fastq2qualitystats.pl <fastq_file> > <output_file>

Where: <fastq_file> is the fastq sequence file.
This program prints to output the average quality score over all reads for each
read position.";
}

my $string = "\@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";

my @a = split(//,$string);

my %qualitychar2score;
for(my $i=0; $i<@a; $i++) {
    $qualitychar2score{$a[$i]} = $i;
}
#foreach my $char (sort {$qualitychar2score{$a} <=> $qualitychar2score{$b}} keys %qualitychar2score) {
#    print "$char: $qualitychar2score{$char}\n";
#}

open(INFILE, $ARGV[0]);
my $num_seqs = 0;
my @sum_of_quals;
while(my $line = <INFILE>) {
    $line = <INFILE>;
    $line = <INFILE>;
    $line = <INFILE>;
#    print $line;
    chomp($line);
    my @a = split(//,$line);
    for(my $i=0; $i<@a; $i++) {
      $sum_of_quals[$i] = $sum_of_quals[$i] + $qualitychar2score{$a[$i]};
#      print "i, $sum_of_quals[$i]\n";
    }
    $num_seqs++;
}
#print "$num_seqs\n";
my @ave_of_quals;
for (my $i=0; $i<@sum_of_quals; $i++) {
  $ave_of_quals[$i] = $sum_of_quals[$i] / $num_seqs;
}

print "POSITION\tAVG_Q\tP\n";
for (my $i=1;$i<=@ave_of_quals;$i++) {
  my $p = 10**(-$ave_of_quals[$i-1]/10);
  print "ave qual position $i\t$ave_of_quals[$i-1]\t$p\n";
}
