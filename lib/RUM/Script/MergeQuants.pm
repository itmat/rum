package RUM::Script::MergeQuants;

no warnings;
use autodie;


use RUM::Logging;
use RUM::CommonProperties;

our $log = RUM::Logging->get_logger();

our @VALID_STRANDS = qw(pa ma ps ms);

use base 'RUM::Script::Base';

sub summary {
    'Merge quantification reports'
}

sub description {
    return <<'EOF';
This script will look in F<dir> for files named quant.1, quant.2,
etc..  up to quant.numchunks.  Unless -strand S is set in which case
it looks for quant.S.1, quant.S.2, etc...
EOF
}

sub accepted_options {
    return (
        RUM::Property->new(
            opt => 'outfile|o=s',
            desc => 'The output file',
        ),
        RUM::Property->new(
            opt => 'chunks|n=s',
            desc => 'The number of chunks',
            required => 1,
        ),
        RUM::CommonProperties->counts_only,
        RUM::Property->new(
            opt => 'alt',
            desc => 'Need this if using --altquant when running RUM',
        ),
        RUM::Property->new(
            opt => 'header',
            desc => 'Print a header row',
        ),
        RUM::CommonProperties->strand_sense,
        RUM::Property->new(
            opt => 'output_dir',
            desc => 'Directory containing quants files',
            positional => 1,
            required => 1,
        ),
    );
}

sub run {

    my ($self) = @_;
    my $props = $self->properties;

    my $outfile    = $props->get('outfile');
    my $numchunks  = $props->get('chunks');
    my $strand     = $props->get('strand');
    my $countsonly = $props->get('countsonly');
    my $alt        = $props->get('alt');
    my $header     = $props->get('header');
    my $output_dir = $props->get('output_dir');
    $num_reads = 0;
    $first = 1;
    my @counts;
    for ($i=1; $i<=$numchunks; $i++) {
        if ($strand) {
            if (!$alt) {
                $filename = "quant.$strand.$i";
            } else {
                $filename = "quant.$strand.altquant.$i";
            }
        } else {
            if (!$alt) {
                $filename = "quant.$i";
            } else {
                $filename = "quant.altquant.$i";
            }
        }

        $log->info("Reading from $filename");

        open INFILE, "$output_dir/$filename";

        $line = <INFILE>;
        $line =~ /num_reads = (\d+)/;
        $num_reads = $num_reads + $1;
        $cnt=0;

        while ($line = <INFILE>) {
            chomp($line);
            @a = split(/\t/,$line);
            $counts[$cnt]{Ucnt} = $counts[$cnt]{Ucnt} + $a[2];
            $counts[$cnt]{NUcnt} = $counts[$cnt]{NUcnt} + $a[3];
            if ($first == 1) {
                $counts[$cnt]{type} = $a[0];
                $counts[$cnt]{coords} = $a[1];
                $counts[$cnt]{len} = $a[4];
                $counts[$cnt]{strand} = $a[5];
                $counts[$cnt]{id} = $a[6];
            }
            $cnt++;
        }
        $first = 0;
    }
    $num_reads_hold = $num_reads;
    $num_reads = $num_reads / 1000000;
    open OUTFILE, ">$outfile";
    print OUTFILE "number of reads used for normalization: $num_reads_hold\n";
    if ($header) {
        print OUTFILE "      Type\tLocation           \tmin\tmax\tUcount\tNUcount\tLength\n";
    }

    for ($i=0; $i<$cnt; $i++) {
        if ($counts[$i]{coords} =~ /:-/) {
            $exoncnt = 1;
            next;
        }
        $NL = $counts[$i]{len} / 1000;
        unless ($NL) {
#            $log->warn("Got 0 NL");
            next;
        }

        if (!$countsonly) {
            $ucnt_normalized = int( $counts[$i]{Ucnt} / $NL / $num_reads * 10000 ) / 10000;
            $totalcnt_normalized = int( ($counts[$i]{NUcnt}+$counts[$i]{Ucnt}) / $NL / $num_reads * 10000 ) / 10000;
        } else {
            $ucnt_normalized = $counts[$i]{Ucnt};
            $totalcnt_normalized = $counts[$i]{NUcnt}+$counts[$i]{Ucnt};
        }
        if ($counts[$i]{type} eq 'transcript') {
            print OUTFILE "--------------------------------------------------------------------\n";
            print OUTFILE "$counts[$i]{id}\t$counts[$i]{strand}\n";
            print OUTFILE "      Type\tLocation           \tmin\tmax\tUcount\tNUcount\tLength\n";
            print OUTFILE "transcript\t$counts[$i]{coords}\t$ucnt_normalized\t$totalcnt_normalized\t$counts[$i]{Ucnt}\t$counts[$i]{NUcnt}\t$counts[$i]{len}\n";
            $exoncnt = 1;
            $introncnt = 1;
        } elsif ($counts[$i]{type} eq 'exon') {
            print OUTFILE "  exon $exoncnt\t$counts[$i]{coords}\t$ucnt_normalized\t$totalcnt_normalized\t$counts[$i]{Ucnt}\t$counts[$i]{NUcnt}\t$counts[$i]{len}\n";
            $exoncnt++;
        } elsif ($counts[$i]{type} eq 'intron') {
            print OUTFILE "intron $introncnt\t$counts[$i]{coords}\t$ucnt_normalized\t$totalcnt_normalized\t$counts[$i]{Ucnt}\t$counts[$i]{NUcnt}\t$counts[$i]{len}\n";
            $introncnt++;
        }
    }
    close(OUTFILE);
}

1;
