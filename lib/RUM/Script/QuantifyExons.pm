package RUM::Script::QuantifyExons;

no warnings;
use RUM::Usage;
use RUM::Logging;
use Getopt::Long;
use RUM::Common qw(roman Roman isroman arabic);
use RUM::Sort qw(cmpChrs);
our $log = RUM::Logging->get_logger();
use strict;
use Data::Dumper;

my %STRAND_MAP = (
    p => '+',
    m => '-'
);

sub read_annot_file {
    use strict;
    my ($annotfile, $wanted_strand, $novel) = @_;
    open my $infile, '<', $annotfile;

    # Skip the header row
    <$infile>;
    my %exons_for_chr;

    while (defined(my $line = <$infile>)) {
        chomp($line);

        my ($loc, $type) = split /\t/, $line;

        if ($novel && $type eq "annotated") {
            next;
        } 

        $loc =~ /^(.*):(\d+)-(\d+)$/ or die "Unexpected input : $line";
        my ($chr, $start, $end) = ($1, $2, $3);

        push @{ $exons_for_chr{$chr} }, { start => $start, end => $end };
    }

    return \%exons_for_chr;

}

sub main {

    my @A;
    my @B;
    my %NUREADS;
    my $UREADS=0;
    
    GetOptions(
        "exons-in=s"      => \(my $annotfile),    
        "unique-in=s"     => \(my $U_readsfile),
        "non-unique-in=s" => \(my $NU_readsfile),
        "output|o=s"      => \(my $outfile1),
        "info=s"          => \(my $infofile),
        "strand=s"        => \(my $wanted_strand),
        "anti"            => \(my $anti),
        "countsonly"      => \(my $countsonly),
        "novel"           => \(my $novel),
        "help|h"          => sub { RUM::Usage->help },
        "verbose|v"       => sub { $log->more_logging(1) },
        "quiet|q"         => sub { $log->less_logging(1) });
    
    $annotfile or RUM::Usage->bad(
        "Please specify an exons file with --exons-in");
    $U_readsfile or RUM::Usage->bad(
        "Please specify a RUM_Unique file with --unique-in");
    $NU_readsfile or RUM::Usage->bad(
        "Please specify a RUM_NU file with --non-unique-in");
    $outfile1 or RUM::Usage->bad(
        "Please specify an output file with -o or --output");

    if ($wanted_strand) {
        $wanted_strand eq 'p' || $wanted_strand eq 'm' or RUM::Usage->bad(
            "--strand must be p or m, not $wanted_strand");
    }

    # read in the transcript models
    my ($EXON) = read_annot_file($annotfile, $wanted_strand, $novel);

    my %EXON = %{ $EXON };

    my $readfile = sub {
        my ($filename, $type) = @_;
        open(INFILE, $filename) or die "ERROR: in script rum2quantifications.pl: cannot open '$filename' for reading.\n\n";

        my $counter=0;
        my $line;

        my %indexstart_e;

        foreach my $chr (keys %EXON) {
            $indexstart_e{$chr} = 0;
        }
        while (defined (my $line = <INFILE>)) {
            chomp($line);
            $counter++;
            if ($counter % 100000 == 0 && !$countsonly) {
                print "$type: counter=$counter\n";
            }

            my @a = split(/\t/,$line);
            my ($readid, $CHR, $locs, $strand) = @a;
            
            $readid =~ /(\d+)/;
            my $seqnum1 = $1;
            if ($type eq "NUcount") {
                $NUREADS{$seqnum1}=1;
            } else {
                $UREADS++;
            }
            if ($wanted_strand) {
                my $same_strand = $STRAND_MAP{$wanted_strand} eq $strand;
                if ($anti) {
                    next if $same_strand;
                }
                else {
                    next if !$same_strand;
                }
            }

            $locs =~ /^(\d+)-/;
            my $start = $1;
            my $end;

            my $line2 = <INFILE>;
            chomp($line2);
            my @b = split(/\t/,$line2);
            $b[0] =~ /(\d+)/;
            my $seqnum2 = $1;
            my $spans_union;
	
            if ($seqnum1 == $seqnum2 && $b[0] =~ /b/ && $readid =~ /a/) {
                my $SPANS;
                if ($strand eq "+") {
                    $b[2] =~ /-(\d+)$/;
                    $end = $1;
                    $SPANS = $a[2] . ", " . $b[2];
                } else {
                    $b[2] =~ /^(\d+)-/;
                    $start = $1;
                    $a[2] =~ /-(\d+)$/;
                    $end = $1;
                    $SPANS = $b[2] . ", " . $a[2];
                }
                #	    my $SPANS = &union($a[2], $b[2]);
                @B = split(/[^\d]+/,$SPANS);
            } else {
                $locs =~ /-(\d+)$/;
                $end = $1;
                # reset the file handle so the last line read will be read again
                my $len = -1 * (1 + length($line2));
                seek(INFILE, $len, 1);
                @B = split(/[^\d]+/,$a[2]);
            }

            my $exons = $EXON{$CHR} || [];

            while ($indexstart_e{$CHR} < @{ $exons } && 
                   $exons->[$indexstart_e{$CHR}]{end} < $start) {
                $indexstart_e{$CHR}++;	
            }

            for my $i ($indexstart_e{$CHR} .. @{ $exons } - 1) {

                my $exon = $EXON{$CHR}[$i];
                if ($end < $exon->{start}) {
                    last;
                }

                my @A = ($exon->{start}, $exon->{end});

                if (do_they_overlap(\@A, \@B)) {
                    $exon->{$type}++;
                }
            }
        }
    };


    $readfile->($U_readsfile, "Ucount");
    $readfile->($NU_readsfile, "NUcount");

    my %EXONhash;
    open my $outfile, '>', $outfile1;
    my $num_reads = $UREADS;
    $num_reads = $num_reads + (scalar keys %NUREADS);
    if ($countsonly) {
        print $outfile "num_reads = $num_reads\n";
    }
    foreach my $chr (sort {cmpChrs($a,$b)} keys %EXON) {

        for my $i (0 .. @{ $EXON{$chr} } - 1) {


            my $exon = $EXON{$chr}[$i];
            my $x1 = $exon->{Ucount}  || 0;
            my $x2 = $exon->{NUcount} || 0;
            my $s  = $exon->{start}   || 0;
            my $e  = $exon->{end}     || 0;
            my $elen = $e - $s + 1;

            print $outfile "exon\t$chr:$s-$e\t$x1\t$x2\t$elen\n";
        }
    }


}


sub union () {
    my ($spans1_u, $spans2_u) = @_;
    
    my %chash;
    my @a = split(/, /,$spans1_u);
    for (my $i=0;$i<@a;$i++) {
        my @b = split(/-/,$a[$i]);
        for (my $j=$b[0];$j<=$b[1];$j++) {
            $chash{$j}++;
        }
    }
    @a = split(/, /,$spans2_u);
    for (my $i=0;$i<@a;$i++) {
        my @b = split(/-/,$a[$i]);
        for (my $j=$b[0];$j<=$b[1];$j++) {
            $chash{$j}++;
        }
    }
    my $first = 1;
    my $spans_union;
    my $pos_prev;
    foreach my $pos (sort {$a<=>$b} keys %chash) {
        if ($first == 1) {
            $spans_union = $pos;
            $first = 0;
        } else {
            if ($pos > $pos_prev + 1) {
                $spans_union = $spans_union . "-$pos_prev, $pos";
            }
        }
        $pos_prev = $pos;
    }
    $spans_union = $spans_union . "-$pos_prev";
    return $spans_union;
}


sub do_they_overlap() {

    my ($A, $B) = @_;

    my $i = 0;
    my $j = 0;
    
    while (1) {
        until (($B->[$j] < $A->[$i] && $i%2==0) || ($B->[$j] <= $A->[$i] && $i%2==1)) {
            $i++;
            if ($i == @$A) {
                return $B->[$j] == $A->[@$A - 1];
            }
        }
        if (($i-1) % 2 == 0) {
            return 1;
        } else {
            $j++;
            if ($j%2==1 && $A->[$i] <= $B->[$j]) {
                return 1;
            }
            if ($j >= @$B) {
                return 0;
            }
        }
    }
}

# seq.35669       chr1    3206742-3206966 -       GCCCACCACCATGTCAAACACAATCTCTTCCCATTTGGTGATACAGAATTCTGTCTCACAGTGGACAATCCAGAAAGTCATGATGCACCAATGGAGGACAATAAATATCCCAAAATACAGCTGGAAAACCGAGGCAAAGAGGGCGAATGTGATGACCCTGGCAGCGATGGTGAAGAAATGCCAGCAGAACTGAATGATGACAGCCATTTAGCTGATGGGCTTTTT
# 
# 
# chr1    -       3195981 3206425 2       3195981,3203689,        3197398,3206425,        OTTMUST00000086625(vega)




1;
