#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

if(@ARGV < 1) {
    die "
Usage: create_indexes_from_ensembl.pl <genome fasta> <gtf>

";
}
$genome = $ARGV[0];
$genome =~ /^(.*)_genome.txt/;
$name = $1;
$F1 = $genome;
$F1 =~ s/.txt$/.fa/;
$gtf = $ARGV[1];

open(INFILE, $ARGV[0]);
$flag = 0;
open(OUTFILE, ">$F1");
while($line = <INFILE>) {
    if($line =~ />/) {
	$line =~ /^>EG:([^\s]+)\s/;
	$chr = $1;
        if($flag == 0) {
            print OUTFILE ">$chr\n";
            $flag = 1;
        } else {
            print OUTFILE "\n>$chr\n";
        }
    } else {
        chomp($line);
        $line = uc $line;
        print OUTFILE $line;
    }
}
print "\n";
close(INFILE);
close(OUTFILE);

$F2 = $genome;
$F2 =~ s/.txt$/_one-line-seqs_temp.fa/;
$F3 = $genome;
$F3 =~ s/.txt$/_one-line-seqs.fa/;

`perl modify_fa_to_have_seq_on_one_line.pl $F1 > $F2`;
`perl sort_genome_fa_by_chr.pl $F2 >  $F3`;

`perl gtf2rum-index-builder-friendly.pl $gtf > ensembl.txt`;
open(OUTFILE, ">gene_info_files");
print OUTFILE "ensembl.txt\n";
close(OUTFILE);

$name1 = $name . "_ensembl";
print "perl create_gene_indexes.pl $name1 $F3\n";
`perl create_gene_indexes.pl $name1 $F3`;

$temp1 = $genome;
$temp1 =~ s/.txt$//;

print STDERR "\nBuilding the bowtie genome index, this could take some time...\n\n";

`bowtie-build $F3 $temp1`;

$N1 = $name1 . "_gene_info_orig.txt";
$N6 = $name1 . "_gene_info.txt";
$F3 = $name1 . "_one-line-seqs.fa";

$name1 = $name1 . "_genes";
$temp2 = $name1 . ".fa";

print STDERR "Building the bowtie gene index...\n\n";

`bowtie-build $temp2 $name1`;

unlink($F1);
unlink($F2);

$config = "indexes/$N6\n";
$config = $config . "bin/bowtie\n";
$config = $config . "bin/blat\n";
$config = $config . "bin/mdust\n";
$config = $config . "indexes/$temp1\n";
$config = $config . "indexes/$name1\n";
$config = $config . "indexes/$F3\n";
$config = $config . "scripts\n";
$config = $config . "lib\n";

$configfile = "rum.config_" . $name;
open(OUTFILE, ">$configfile");
print OUTFILE $config;
close(OUTFILE);

print STDERR "ok, all done...\n\n";
