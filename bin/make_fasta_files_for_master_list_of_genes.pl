#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

if(@ARGV<4) {
    die "
Usage: make_fasta_file_for_master_list_of_genes.pl <genome fasta> <exons> <gene info input file> <gene info output file>

This script is part of the pipeline of scripts used to create RUM indexes.
You should probably not be running it alone.  See the library file:
'how2setup_genome-indexes_forPipeline.txt'.

Note: this script will remove from the gene input file anything on a chromosome
for which there is no sequence in the <genome fasta> file.

";
}

$final_gene_info_file = $ARGV[3];

# Note: fasta file $ARGV[0] must have seq all on one line
open(INFILE, $ARGV[0]) or die "ERROR: cannot open '$ARGV[0]' for reading\n";
$line = <INFILE>;
chomp($line);
$line =~ />(.*)/;
$chr = $1; 
print STDERR "$line\n";
$chr_hash1{$chr}++;
until($line eq '') {
    $line = <INFILE>;
    chomp($line);
    $seq = $line;
    &get_exons($chr, $seq);
    print STDERR "done with exons for $chr\n";
    &get_genes($chr, $seq);
    print STDERR "done with genes for $chr\n";
    $line = <INFILE>;
    chomp($line);
    print STDERR "$line\n";
    $line =~ />(.*)/;
    $chr = $1; 
    $chr_hash1{$chr}++;
}
close(INFILE);

$str = "cat $ARGV[2]";
$flag = 0;
foreach $key (keys %chr_hash2) {
    if($chr_hash1{$key}+0==0) {
	if($flag == 0) {
	    print STDERR "no sequence for:\n$key\n";
	    $flag = 1;
	} else {
	    print STDERR "$key\n";
	}
	$str = $str .  " | grep -v $key";
    }
}
if($flag == 1) {
    print STDERR "Removing the genes on the chromosomes for which there was no genome sequence.\n";
    $str = $str . " > $final_gene_info_file";
    print STDERR "str:\n$str\n";
    `$str`;
} else {
    $fn = $ARGV[2];
    `mv $fn $final_gene_info_file`;
}

sub get_exons () {
    ($chr, $seq) = @_;

    undef %exons;
    open(EXONINFILE, $ARGV[1]) or die "ERROR: cannot open '$ARGV[1]' for reading.\n";
    while($line2 = <EXONINFILE>) {
	chomp($line2);
	$line2 =~ /(.*):(\d+)-(\d+)/;
	$CHR = $1;
	$START = $2;
	$END = $3;
	$chr_hash2{$CHR}++;
	if($CHR eq $chr) {
	    $EXONSEQ = substr($seq,$START-1,$END-$START+1);
	    $exons{$line2} = $EXONSEQ;
	}
    }
    close(EXONINFILE);
}

sub get_genes () {
    ($chr, $seq) = @_;

    open(GENEINFILE, $ARGV[2]) or die "ERROR: cannot open '$ARGV[2]' for reading.\n";
    while($line2 = <GENEINFILE>) {
	chomp($line2);
	@a = split(/\t/,$line2);
	$strand = $a[1];
	$starts = $a[5];
	$ends = $a[6];
	$starts =~ s/\s*,\s*$//;
	$ends =~ s/\s*,\s*$//;
	@STARTS = split(/,/,$starts);
	@ENDS = split(/,/,$ends);
	$CHR = $a[0];
	if($CHR eq $chr) {
	    $GENESEQ = "";
	    for($i=0; $i<@STARTS; $i++) {
		$s = $STARTS[$i] + 1;  # add one because of the pesky zero based ucsc coords
		$e = $ENDS[$i];  # don't add one to the end, because of the pesky half-open based ucsc coords
		$ex = "$CHR:$s-$e";
		$GENESEQ = $GENESEQ . $exons{$ex};
		if(!($exons{$ex} =~ /\S/)) {
		    die "ERROR: exon for $ex not found.\n$line2\ni=$i\n";
		}
	    }
	    $a[7] =~ s/::::.*//;
	    $a[7] =~ s/\([^\(]+$//;
	    print ">$a[7]:$CHR:$a[2]-$a[3]_$a[1]\n";
	    if($a[1] eq '-') {
		$SEQ = &reversecomplement($GENESEQ);
	    } else {
		$SEQ = $GENESEQ;
	    }
	    print "$SEQ\n";
	}
    }
    close(GENEINFILE);
    close(GENEOUTFILE);
}


sub reversecomplement () {
    ($sq) = @_;
    @A = split(//,$sq);
    $rev = "";
    for($i=@A-1; $i>=0; $i--) {
        $flag = 0;
        if($A[$i] eq 'A') {
            $rev = $rev . "T";
            $flag = 1;
        }
        if($A[$i] eq 'T') {
            $rev = $rev . "A";
            $flag = 1;
        }
        if($A[$i] eq 'C') {
            $rev = $rev . "G";
            $flag = 1;
        }
        if($A[$i] eq 'G') {
            $rev = $rev . "C";
            $flag = 1;
        }
        if($flag == 0) {
            $rev = $rev . $A[$i];
        }
    }
    return $rev;
}
