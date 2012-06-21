package RUM::Script::QuantifyExons;

no warnings;
use RUM::Usage;
use RUM::Logging;
use Getopt::Long;
use RUM::Common qw(roman Roman isroman arabic);
use RUM::Sort qw(cmpChrs);
our $log = RUM::Logging->get_logger();
use strict;


sub main {


    

    my %EXON_temp;
    my %cnt;
    my @A;
    my @B;
    my %ecnt;
    my %NUREADS;
    my $UREADS=0;
    
    my $strand = "";
    my $strandspecific;

    GetOptions(
        "exons-in=s"  => \(my $annotfile),    
        "unique-in=s" => \(my $U_readsfile),
        "non-unique-in=s" => \(my $NU_readsfile),
        "output|o=s" => \(my $outfile1),
        "info=s"   => \(my $infofile),
        "strand=s" => \(my $userstrand),
        "anti"     => \(my $anti),
        "countsonly" => \(my $countsonly),
        "novel"      => \(my $novel),
        "help|h"    => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) });
    
    $annotfile or RUM::Usage->bad(
        "Please specify an exons file with --exons-in");
    $U_readsfile or RUM::Usage->bad(
        "Please specify a RUM_Unique file with --unique-in");
    $NU_readsfile or RUM::Usage->bad(
        "Please specify a RUM_NU file with --non-unique-in");
    $outfile1 or RUM::Usage->bad(
        "Please specify an output file with -o or --output");

    if ($userstrand) {
        $strand = $userstrand;
        $strandspecific = 1;
        $strand eq 'p' || $strand eq 'm' or RUM::Usage->bad(
            "--strand must be p or m, not $strand");
    }


    # read in the info file, if given

    my %INFO;
    if ($infofile) {
        open(INFILE, $infofile) 
            or die "Can't open $infofile for reading: $!";
        while (my $line = <INFILE>) {
            chomp($line);
            my @a = split(/\t/,$line);
            $INFO{$a[0]} = $a[1];
        }
        close(INFILE);
    }

# read in the transcript models

    open(INFILE, $annotfile) or die "ERROR: in script rum2quantifications.pl: cannot open '$annotfile' for reading.\n\n";
my %EXON;
my %CHRS;
    while (my $line = <INFILE>) {
        chomp($line);
        my @a = split(/\t/,$line);
        if ($novel && $a[1] eq "annotated") {
            next;
        } 
        if ($strandspecific) {
            if ($strand =~ /^p/ && $a[1] eq '-') { # fix this when fix strand specific, strand is no longer a[1]
                next;
            }
            if ($strand =~ /^m/ && $a[1] eq '+') {
                next;
            }
        }
        $a[0] =~ /^(.*):(\d+)-(\d+)$/;
        my $chr = $1;
        my $start = $2;
        my $end = $3;
        if ($CHRS{$chr}+0==0) {
            $ecnt{$chr} = 0;
            $CHRS{$chr}=1;
        }
        $EXON{$chr}[$ecnt{$chr}]{start} = $start;
        $EXON{$chr}[$ecnt{$chr}]{end} = $end;
        $ecnt{$chr}++;
    }

    my $readfile = sub {
        my ($filename, $type) = @_;
        open(INFILE, $filename) or die "ERROR: in script rum2quantifications.pl: cannot open '$filename' for reading.\n\n";
        my %HASH;
        my $counter=0;
        my $line;
        my %indexstart_t;
        my %indexstart_e;
        my %indexstart_i;
        foreach my $chr (keys %EXON) {
            $indexstart_e{$chr} = 0;
        }
        while ($line = <INFILE>) {
            $counter++;
            if ($counter % 100000 == 0 && !$countsonly) {
                print "$type: counter=$counter\n";
            }
            chomp($line);
            if ($line eq '') {
                last;
            }
            my @a = split(/\t/,$line);
            my $STRAND = $a[3];
            $a[0] =~ /(\d+)/;
            my $seqnum1 = $1;
            if ($type eq "NUcount") {
                $NUREADS{$seqnum1}=1;
            } else {
                $UREADS++;
            }
            if ($strandspecific) {
                if ($strand eq 'p' && $STRAND eq '-' && !$anti) {
                    next;
                }
                if ($strand eq 'm' && $STRAND eq '+' && !$anti) {
                    next;
                }
                if ($strand eq 'p' && $STRAND eq '+' && $anti) {
                    next;
                }
                if ($strand eq 'm' && $STRAND eq '-' && $anti) {
                    next;
                }
            }
            my $CHR = $a[1];
            $HASH{$CHR}++;
            #	if($HASH{$CHR} == 1) {
            #	    print "CHR: $CHR\n";
            #	}
            $a[2] =~ /^(\d+)-/;
            my $start = $1;
            my $end;
            my $line2 = <INFILE>;
            chomp($line2);
            my @b = split(/\t/,$line2);
            $b[0] =~ /(\d+)/;
            my $seqnum2 = $1;
            my $spans_union;
	
            if ($seqnum1 == $seqnum2 && $b[0] =~ /b/ && $a[0] =~ /a/) {
                my $SPANS;
                if ($a[3] eq "+") {
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
                @B = split(/[^\d]+/,$SPANS);
            } else {
                $a[2] =~ /-(\d+)$/;
                $end = $1;
                # reset the file handle so the last line read will be read again
                my $len = -1 * (1 + length($line2));
                seek(INFILE, $len, 1);
                @B = split(/[^\d]+/,$a[2]);
            }
            while ($EXON{$CHR}[$indexstart_e{$CHR}]{end} < $start && $indexstart_e{$CHR} <= $ecnt{$CHR}) {
                $indexstart_e{$CHR}++;	
            }
            my $i = $indexstart_e{$CHR};
            my $flag = 0;
            while ($flag == 0) {
                $ecnt{$CHR} = $ecnt{$CHR}+0;
                if ($end < $EXON{$CHR}[$i]{start} || $i >= $ecnt{$CHR}) {
                    last;
                }
                undef @A;
                $A[0] = $EXON{$CHR}[$i]{start};
                $A[1] = $EXON{$CHR}[$i]{end};
                my $b = &do_they_overlap(\@A, \@B);
                if ($b == 1) {
                    $EXON{$CHR}[$i]{$type}++;
                }
                $i++;
            }
        }
    };


    $readfile->($U_readsfile, "Ucount");
    $readfile->($NU_readsfile, "NUcount");

    my %EXONhash;
    open(OUTFILE1, ">$outfile1") or die "ERROR: in script rum2quantifications.pl: cannot open file '$outfile1' for writing.\n\n";
    my $num_reads = $UREADS;
    $num_reads = $num_reads + (scalar keys %NUREADS);
if ($countsonly) {
        print OUTFILE1 "num_reads = $num_reads\n";
    }
    foreach my $chr (sort {cmpChrs($a,$b)} keys %EXON) {
        for (my $i=0; $i<$ecnt{$chr}; $i++) {
            my $x1 = $EXON{$chr}[$i]{Ucount}+0;
            my $x2 = $EXON{$chr}[$i]{NUcount}+0;
            my $s = $EXON{$chr}[$i]{start};
            my $e = $EXON{$chr}[$i]{end};
            my $elen = $e - $s + 1;
            #	print OUTFILE1 "transcript\t$chr:$s-$e\t$x1\t$x2\t$elen\t+\t$chr:$s-$e\n";
            print OUTFILE1 "exon\t$chr:$s-$e\t$x1\t$x2\t$elen\n";
        }
    }


}

sub do_they_overlap {

    my ($A, $B) = @_;

    my $i=0;
    my $j=0;
    
    while (1==1) {
        until (($B->[$j] < $A->[$i] && $i%2==0) || ($B->[$j] <= $A->[$i] && $i%2==1)) {
            $i++;
            if ($i == @$A) {
                if ($B->[$j] == $A->[@$A-1]) {
                    return 1;
                } else {
                    return 0;
                }
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
