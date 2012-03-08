package RUM::Script::MakeUnmappedFile;

no warnings;

use RUM::Logging;
use RUM::Usage;
use Getopt::Long;

sub main {

    # FIX THIS SO THAT READS CAN SPAN MORE THAN ONE LINE IN THE FASTA FILE
    $infile = $ARGV[0];
    $infile1 = $ARGV[1];
    $infile2 = $ARGV[2];
    $outfile = $ARGV[3];
    $type = $ARGV[4];
    $typerecognized = 1;
    if ($type eq "single") {
        $paired_end = "false";
        $typerecognized = 0;
    }
    if ($type eq "paired") {
        $paired_end = "true";
        $typerecognized = 0;
    }
    if ($typerecognized == 1) {
        die "\nERROR: in script make_unmapped.pl: type '$type' not recognized.  Must be 'single' or 'paired'.\n";
    }

    open(INFILE, $infile1) or die "\nERROR: in script make_unmapped.pl: Cannot open file '$infile1' for reading\n";
    while ($line = <INFILE>) {
        chomp($line);
        $line =~ s/\t.*//;
        if (!($line =~ /(a|b)/)) {
            $bu{$line}=2;
        } else {
            $line =~ s/(a|b)//;
            $bu{$line}++;
        }
    }
    close(INFILE);

    open(INFILE, $infile2) or die "\nERROR: in script make_unmapped.pl: Cannot open file '$infile2' for reading\n";
    while ($line = <INFILE>) {
        chomp($line);
        $line =~ s/\t.*//;
        $line =~ s/(a|b)//;
        $bnu{$line}++;
    }
    close(INFILE);

    open(INFILE, $infile) or die "\nERROR: in script make_unmapped.pl: Cannot open file '$infile' for reading\n";

    open(OUTFILE, ">$outfile") or die "\nERROR: in script make_unmapped.pl: Cannot open file '$outfile' for writing\n";

    while ($line = <INFILE>) {
        chomp($line);
        if ($line =~ /^>(seq.\d+)/) {
            $seq = $1;
            if ($paired_end eq "true") {
                if ($bu{$seq}+0 < 2 && !($bnu{$seq} =~ /\S/)) {
                    $line_hold = $line;
                    $line = <INFILE>;
                    chomp($line);
                    print OUTFILE "$line_hold\n";
                    print OUTFILE "$line\n";
                    $line_hold = <INFILE>;
                    chomp($line_hold);
                    $line = <INFILE>;
                    chomp($line);
                    print OUTFILE "$line_hold\n";
                    print OUTFILE "$line\n";
                }
            } else {
                if ($bu{$seq}+0 < 1 && !($bnu{$seq} =~ /\S/)) {
                    $line_hold = $line;
                    $line = <INFILE>;
                    chomp($line);
                    print OUTFILE "$line_hold\n";
                    print OUTFILE "$line\n";
                }
            }
        }
    }
    close(INFILE);
    close(OUTFILE);

    print "Starting BLAT on '$outfile'.\n";
}

1;
