#!/usr/bin/perl

use strict;
use warnings;
use autodie;


# Written by Gregory R. Grant
# University of Pennsylvania, 2010

if(@ARGV < 2) {
    die "
Usage: sam2xs-flag.pl <sam file> <genome seq>

";
}

my $genome_sequence = $ARGV[1];

$|=1;

my (@donor, @donor_rev, @acceptor, @acceptor_rev);

# Splice Junctions:
# ----------------
# The Canonical:
#  GTAG
$donor[0] = "GT";
$donor_rev[0] = "AC";
$acceptor[0] = "AG";
$acceptor_rev[0] = "CT";
# Other Characterized:
#  GCAG
$donor[1] = "GC";
$donor_rev[1] = "GC";
$acceptor[1] = "AG";
$acceptor_rev[1] = "CT";
#  GCTG
$donor[2] = "GC";
$donor_rev[2] = "GC";
$acceptor[2] = "TG";
$acceptor_rev[2] = "CA";
#  GCAA
$donor[3] = "GC";
$donor_rev[3] = "GC";
$acceptor[3] = "AA";
$acceptor_rev[3] = "TT";
#  GCCG
$donor[4] = "GC";
$donor_rev[4] = "GC";
$acceptor[4] = "CG";
$acceptor_rev[4] = "CG";
#  GTTG
$donor[5] = "GT";
$donor_rev[5] = "AC";
$acceptor[5] = "TG";
$acceptor_rev[5] = "CA";
#  GTAA
$donor[6] = "GT";
$donor_rev[6] = "AC";
$acceptor[6] = "AA";
$acceptor_rev[6] = "TT";
# U12-dependent:
#  ATAC
$donor[7] = "AT";
$donor_rev[7] = "AT";
$acceptor[7] = "AC";
$acceptor_rev[7] = "GT";
#  ATAA
$donor[8] = "AT";
$donor_rev[8] = "AT";
$acceptor[8] = "AA";
$acceptor_rev[8] = "TT";
#  ATAG
$donor[9] = "AT";
$donor_rev[9] = "AT";
$acceptor[9] = "AG";
$acceptor_rev[9] = "CT";
#  ATAT
$donor[10] = "AT";
$donor_rev[10] = "AT";
$acceptor[10] = "AT";
$acceptor_rev[10] = "AT";

#  TAGA
$donor[11] = "TA";
$donor_rev[11] = "TA";
$acceptor[11] = "GA";
$acceptor_rev[11] = "TC";

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
