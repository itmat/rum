package RUM::Script::MergeQuants;

no warnings;
use RUM::Usage;

use base 'RUM::Script::Base';

our @VALID_STRANDS = qw(pa ma ps ms);

sub main {
    my $self = __PACKAGE__->new;

    $self->get_options(
        "output|o=s" => \(my $outfile),
        "chunks|n=s" => \(my $numchunks),
        "strand=s"   => \(my $strand),
        "countsonly"       => \(my $countsonly),
        "alt"              => \(my $alt),
        "header"           => \(my $header));

    my $output_dir = shift(@ARGV) or RUM::Usage->bad(
        "Please provide the directory containing the quant.* files");

    $outfile or RUM::Usage->bad(
        "Please specify an output file with o or --output");

    $numchunks or RUM::Usage->bad(
        "Please indicate the number of chunks with -n or --chunks");

    if ($strand) {
        grep { $_ eq $strand } @VALID_STRANDS or RUM::Usage->bad(
            "--strand must be one of (@VALID_STRANDS), not '$strand'");
    }
    
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

        $self->logger->info("Reading from $filename");

        open(INFILE, "$output_dir/$filename")
            or die "Can't open $output_dir/$filename for reading: $!";

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
    open(OUTFILE, ">$outfile") 
        or die "Can't open $output_dir/$outfile for writing: $!";
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

__END__

=head1 NAME

RUM::Script::MergeQuants

=head1 METHODS

=over 4

=item RUM::Script::MergeQuants->main

Run the script.

=back

=head1 AUTHORS

Gregory Grant (ggrant@grant.org)

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012, University of Pennsylvania


