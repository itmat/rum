package RUM::Script::MakeUnmappedFile;

no warnings;

use RUM::Logging;
use RUM::Usage;
use Getopt::Long;
use RUM::CommonProperties;

use base 'RUM::Script::Base';

our $log = RUM::Logging->get_logger();

sub summary {
    'Build file of reads that remain unmapped after bowtie'
}

sub description {
    return <<'EOF';
Reads in a reads file and files of unique and non-unique mappings
obtained from bowtie, and outputs a file of reads that remain
unmapped.
EOF
}

# FIX THIS SO THAT READS CAN SPAN MORE THAN ONE LINE IN THE FASTA FILE

sub accepted_options {
    return (
        RUM::Property->new(
            opt => 'reads-in=s',
            desc => 'The FASTA file of reads',
            required => 1),
        RUM::CommonProperties->unique_in->set_required,
        RUM::CommonProperties->non_unique_in->set_required,
        RUM::Property->new(
            opt => 'output=s',
            desc => 'The file to write the unmapped reads to',
            required => 1),
        RUM::CommonProperties->read_type
    );
}

sub run {
    my ($self) = @_;
    my $props = $self->properties;

    my $infile = $props->get('reads_in');
    my $infile1 = $props->get('unique_in');
    my $infile2 = $props->get('non_unique_in');
    my $outfile = $props->get('output');
    my $single = $props->get('type') eq 'single';
    my $paired = $props->get('type') eq 'paired';

    # Check command line args

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
