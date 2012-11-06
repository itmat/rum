#!/usr/bin/perl

use strict;
use warnings;
use autodie;
use lib 'lib';

use RUM::SpliceSignals;

my @donor = RUM::SpliceSignals->donor;
my @donor_rev = RUM::SpliceSignals->donor_rev;
my @acceptor = RUM::SpliceSignals->acceptor;
my @acceptor_rev = RUM::SpliceSignals->acceptor_rev;

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

if(@ARGV < 2) {
    die "
Usage: sam2xs-flag.pl <sam file> <genome seq>

";
}

my $genome_sequence = $ARGV[1];

$|=1;

sub load_genome {
    my ($genome_filename) = @_;
    my %seq_for_chr;

    open my $genome_fh, '<', $genome_filename;
    while (defined (my $line = <$genome_fh>)) {
        chomp($line);
        $line =~ s/^>//;
        my $name = $line;
        $line = <$genome_fh>;
        chomp($line);
        $seq_for_chr{$name} = $line;
    }
    return \%seq_for_chr;
}

my $seq_for_chr = load_genome($genome_sequence);

open my $infile, $ARGV[0];
my $line = <$infile>;
while ($line =~ /^@..\t/) {
    $line = <$infile>;
}

sub xs_a_tag_for_intron {
    my ($upstream, $downstream) = @_;
    
    for my $sig (0 .. $#donor) {
        if ($upstream eq $donor[$sig] && $downstream eq $acceptor[$sig]) {
            return "XS:A:+";
        }
        elsif ($upstream eq $acceptor_rev[$sig] && $downstream eq $donor_rev[$sig]) {
            return "XS:A:-";
        }
    }
    return;
}

while (defined $line) {
    chomp $line;
    my ($qname, $flag, $rname, $pos, $mapq, $cigar, $rnext, $pnext, $tlen, 
        $seq, $qual, @optional) = split /\t/, $line;
    my $xs_tag = xs_a_tag_for_sam($rname, $pos, $cigar, $seq_for_chr);
    if (defined($xs_tag)) {
        print "$line\t$xs_tag\n";
    }
    else {
        print "$line\n";
    }
    $line = <$infile>;
}

sub xs_a_tag_for_sam {
    my ($rname, $pos, $cigar, $seq_for_rname) = @_;
    my $intron_at_span;
    $rname =~ s/:.*//;

    # Examine the CIGAR string to build up a list of spans, and mark a
    # span (in $intron_at_span) that is over an intron.
    my @spans;
    while($cigar =~ /^(\d+)([^\d])/) {
        my ($num, $type) = ($1, $2);

	if ($type eq 'M') {
	    my $E = $pos + $num - 1;
            push @spans, [$pos, $E];
	    $pos = $E;
	}
	if ($type eq 'D' || $type eq 'N') {
	    $pos = $pos + $num + 1;
	}
        if ($type eq 'N') {
	    $intron_at_span = $#spans;
	}
	if ($type eq 'I') {
	    $pos++;
	}
	$cigar =~ s/^\d+[^\d]//;
    }

    return if ! defined $intron_at_span;

    my $istart = $spans[$intron_at_span    ][1] + 1;
    my $iend   = $spans[$intron_at_span + 1][0] - 1;

    my $upstream   = substr $seq_for_rname->{$rname}, $istart - 1, 2;
    my $downstream = substr $seq_for_rname->{$rname}, $iend   - 2, 2;
    
    return xs_a_tag_for_intron($upstream, $downstream);
}
