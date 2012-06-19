
if(@ARGV<2) {
    print "
This script converts a .cov file into a bigwig file.  The point of
a bigwig file is to host it locally and just tell the genome browser
where it is, instead of uploading the whole .cov file to the browser.
This is necessary when the .cov file is too big to upload.

Usage: make_bigwig.pl <cov file> <output file> <species>

Where:
       <cov file> is a coverage file as output by
       rum (usually called RUM_unique.cov or RUM_NU.cov)

       <output file> the name of the bigwig output file
       (it should have suffix .bw)

       <species> is mm9 or hg19 or whatever else you have chr sizes for

In the same directory as this script you must have two things:
1) bedGraphToBigWig (with executable permissions)
   you can get it here: http://itmat.rum.s3.amazonaws.com/bedGraphToBigWig
2) a file with the chromosome sizes.  You can get mouse or human here:
    - http://itmat.rum.s3.amazonaws.com/mm9.chrom.sizes
    - http://itmat.rum.s3.amazonaws.com/hg19.chrom.sizes

There will be two output files:

  1) the bigwig file itself, upload it to some public html space.
  
  2) a file that ends in trackdefline.txt which has what you paste
  into the custom track text box on the UCSC genome browser.  Replace
  NAME with a name for this track and replace URL with the address of
  the .bw file.

";
    exit();
}

$covfile = $ARGV[0];
$outfile = $ARGV[1];

if(!($outfile =~ /\.bw$/)) {
    $outfile = $outfile . ".bw";
}
`grep -v track $covfile > x.cov`;
`sort -k1,1 -k2,2n x.cov > x_sorted.cov`;
`./bedGraphToBigWig x_sorted.cov $ARGV[2].chrom.sizes $outfile`;
`yes|rm x.cov`;
`yes|rm x_sorted.cov`;

$outfile2 = $outfile;
$outfile2 =~ s/.bw$/_trackdefline.txt/;
open(OUTFILE, ">$outfile2");
print OUTFILE "track type=bigWig name=\"NAME\" description=\"NAME\" visibility=full itemRgb=On color=255,0,0 priority=10 bigDataUrl=URL\n";
close(OUTFILE);
