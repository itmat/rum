package RUM::Script::MakeUnmappedFile;

no warnings;

use RUM::Logging;
use RUM::Usage;
use Getopt::Long;

our $log = RUM::Logging->get_logger();

# FIX THIS SO THAT READS CAN SPAN MORE THAN ONE LINE IN THE FASTA FILE

sub main {

    GetOptions(
        "reads-in=s"      => \(my $infile),
        "unique-in=s"     => \(my $infile1),
        "non-unique-in=s" => \(my $infile2),
        "output|o=s"      => \(my $outfile),
        "single"          => \(my $single),
        "paired"          => \(my $paired),
        "verbose|v"       => sub { $log->more_logging(1) },
        "quiet|q"         => sub { $log->less_logging(1) },
        "help|h"          => sub { RUM::Usage->help });

    # Check command line args
    $infile or RUM::Usage->bad(
        "Please provide a reads file with --reads-in");
    $infile1 or RUM::Usage->bad(
        "Please provide a unique mapper file with --unique-in");
    $infile2 or RUM::Usage->bad(
        "Please provide a non-unique mapper file with --non-unique-in");
    $outfile or RUM::Usage->bad(
        "Please specify an output file with --output or -o");
    ($paired xor $single) or RUM::Usage->bad(
        "Please specify exactly one of --paired or --single");

    $log->debug("Reading unique mappers");
    open(INFILE, "<", $infile1) or die "Can't open $infile1 for reading: $!";
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

    $log->debug("Reading non-unique mappers");
    open(INFILE, "<", $infile2) or die "Can't open $infile2 for reading: $!";
    while ($line = <INFILE>) {
        chomp($line);
        $line =~ s/\t.*//;
        $line =~ s/(a|b)//;
        $bnu{$line}++;
    }
    close(INFILE);

    $log->debug("Filtering mapped reads");
    open(INFILE, $infile) or die "Can't open $infile for reading: $!";
    open(OUTFILE, ">", $outfile) or die "Can't open $outfile for reading: $!";

    while ($line = <INFILE>) {
        chomp($line);
        if ($line =~ /^>(seq.\d+)/) {
            $seq = $1;
            if ($paired) {
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
    
    $log->info("Starting BLAT on '$outfile'.");
    return 0;
}

1;
