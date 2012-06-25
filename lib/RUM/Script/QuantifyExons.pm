package RUM::Script::QuantifyExons;

use strict;
no warnings;
use autodie;

use RUM::Usage;
use RUM::Logging;
use Getopt::Long;
use RUM::Common qw(roman Roman isroman arabic);
use RUM::Sort qw(cmpChrs);
use RUM::RUMIO;
our $log = RUM::Logging->get_logger();

sub main {

    my %ecnt;
    
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

    !$userstrand or $userstrand eq 'p' or $userstrand eq 'm' or RUM::Usage->bad(
        "--strand must be p or m, not $userstrand");

    # read in the info file, if given

    my %INFO;
    if ($infofile) {
        open INFILE, "<", $infofile;
        while (my $line = <INFILE>) {
            chomp($line);
            my @a = split(/\t/,$line);
            $INFO{$a[0]} = $a[1];
        }
        close(INFILE);
    }

    # read in the transcript models
    
    open INFILE, "<", $annotfile;
    my %EXON;
    my %CHRS;
    while (my $line = <INFILE>) {
        chomp($line);
        my @a = split(/\t/,$line);
        if ($novel && $a[1] eq "annotated") {
            next;
        } 
        if ($userstrand) {
            if ($userstrand =~ /^p/ && $a[1] eq '-') { # fix this when fix strand specific, strand is no longer a[1]
                next;
            }
            if ($userstrand =~ /^m/ && $a[1] eq '+') {
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

    my %nureads;
    my $ureads;
    readfile($U_readsfile, "Ucount", sub { $ureads++ }, \%EXON, $userstrand, $anti, \%ecnt, $countsonly);
    readfile($NU_readsfile, "NUcount", sub { $nureads{$_[0]->order} = 1 }, \%EXON, $userstrand, $anti, \%ecnt, $countsonly);

    my %EXONhash;
    open OUTFILE1, ">", $outfile1;
    if ($countsonly) {
        printf OUTFILE1 "num_reads = %d\n", $ureads + keys(%nureads);
    }
    foreach my $chr (sort {cmpChrs($a,$b)} keys %EXON) {
        for (my $i=0; $i<$ecnt{$chr}; $i++) {
            my $x1   = $EXON{$chr}[$i]{Ucount} || 0;
            my $x2   = $EXON{$chr}[$i]{NUcount} || 0;
            my $s    = $EXON{$chr}[$i]{start};
            my $e    = $EXON{$chr}[$i]{end};
            my $elen = $e - $s + 1;
            #	print OUTFILE1 "transcript\t$chr:$s-$e\t$x1\t$x2\t$elen\t+\t$chr:$s-$e\n";
            print OUTFILE1 "exon\t$chr:$s-$e\t$x1\t$x2\t$elen\n";
        }
    }


}

sub readfile {
    my ($filename, $type, $callback, $exon, $userstrand, $anti, $ecnt, $countsonly) = @_;
    
    my $iter = RUM::RUMIO->new(-file => $filename)->peekable;
    my $counter = 0;
    my %indexstart_e = map { ($_ => 0) } keys %$exon;
    
    while (my $aln = $iter->next_val) {
        $counter++;
        if ($counter % 100000 == 0 && !$countsonly) {
            print "$type: counter=$counter\n";
        }
        
        $callback->($aln);
        
        # Skip if we're doing strand-specific and this strand
        # doesn't match the combination of --strand and --anti
        # given by the user.
        if ($userstrand) {
            my $aln_strand = $aln->strand;
            next if $userstrand eq 'p' && $aln_strand eq '-' && !$anti;
            next if $userstrand eq 'm' && $aln_strand eq '+' && !$anti;
            next if $userstrand eq 'p' && $aln_strand eq '+' &&  $anti;
            next if $userstrand eq 'm' && $aln_strand eq '-' &&  $anti;
        }
        
        my $CHR = $aln->chromosome;
        
        my ($start, $end, @spans);
        
        if ($aln->is_mate($iter->peek)) {
            
            my $next_aln = $iter->next_val;
            
            if ($aln->strand eq "+") {
                ($start, $end) = ($aln->start, $next_aln->end);
                @spans = (@{ $aln->locs }, 
                          @{ $next_aln->locs });
            } else {
                ($start, $end) = ($next_aln->start, $aln->end);
                @spans = (@{ $next_aln->locs }, 
                          @{ $aln->locs });
            }
        } else {
            ($start, $end) = ($aln->start, $aln->end);
            @spans = @{ $aln->locs };
        }
        
        my @flattened_spans = map { @$_ } @spans;
        
        while ($exon->{$CHR}[$indexstart_e{$CHR}]{end} < $start 
               && $indexstart_e{$CHR} <= $ecnt->{$CHR}) {
            $indexstart_e{$CHR}++;	
        }
        
        my $i = $indexstart_e{$CHR};
        while ($end >= $exon->{$CHR}[$i]{start} 
               && $i < ($ecnt->{$CHR} || 0)) {
            
            my @A = ( $exon->{ $CHR }[ $i ]{ start },
                      $exon->{ $CHR }[ $i ]{ end   } );
            
            if (do_they_overlap(\@A, \@flattened_spans)) {
                $exon->{$CHR}[$i]{$type}++;
            }
            $i++;
        }
    }
};




sub do_they_overlap {

    my ($A, $B) = @_;

    my $i=0;
    my $j=0;
    
    while (1) {
        until (($B->[$j] <  $A->[$i] && $i%2==0) ||
               ($B->[$j] <= $A->[$i] && $i%2==1)) {
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
