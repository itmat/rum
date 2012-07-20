package RUM::Script::QuantifyExons;

use strict;
no warnings;
use autodie;

use RUM::Usage;
use RUM::Common qw(roman Roman isroman arabic);
use RUM::Sort qw(cmpChrs);
use RUM::RUMIO;

use base 'RUM::Script::Base';

sub main {
    
    my $self = __PACKAGE__->new;
    my %ecnt;
    
    $self->get_options(
        "exons-in=s"      => \(my $annotfile),    
        "unique-in=s"     => \(my $U_readsfile),
        "non-unique-in=s" => \(my $NU_readsfile),
        "output|o=s"      => \(my $outfile1),
        "info=s"          => \(my $infofile),
        "strand=s"        => \(my $userstrand = ""),
        "anti"            => \(my $anti),
        "countsonly"      => \(my $countsonly),
        "novel"           => \(my $novel));
    
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

    # read in the info file, if given TODO: We don't seem to do
    # anything with this data, we just read it in and put it in the
    # %INFO hash, but don't ever use it.
    # my %INFO;
    # if ($infofile) {
    #     open INFILE, "<", $infofile;
    #     while (my $line = <INFILE>) {
    #         chomp($line);
    #         my @a = split(/\t/,$line);
    #         $INFO{$a[0]} = $a[1];
    #     }
    #     close(INFILE);
    # }

    # read in the transcript models
    
    open INFILE, "<", $annotfile;
    my %EXON;

    while (my $line = <INFILE>) {
        chomp($line);
        my @fields = split(/\t/,$line);
        next if $novel && $fields[1] eq "annotated";
        # fix this when fix strand specific, strand is no longer fields[1]
        next if $userstrand =~ /^p/ && $fields[1] eq '-';
        next if $userstrand =~ /^m/ && $fields[1] eq '+';

        my ($chr, $start, $end) = $fields[0] =~ /^(.*):(\d+)-(\d+)$/g;

        push @{ $EXON{$chr} } , { start => $start, end => $end };
    }

    my %ecnt = map { ($_ => scalar(@{ $EXON{$_} })) } keys %EXON;

    my %nureads;
    my $ureads;

    readfile($U_readsfile, "Ucount", sub { $ureads++ }, \%EXON, $userstrand, $anti, $countsonly);
    readfile($NU_readsfile, "NUcount", sub { $nureads{$_[0]->order} = 1 }, \%EXON, $userstrand, $anti, $countsonly);

    open OUTFILE1, ">", $outfile1;
    if ($countsonly) {
        printf OUTFILE1 "num_reads = %d\n", $ureads + keys(%nureads);
    }
    for my $chr (sort {cmpChrs($a,$b)} keys %EXON) {
        my $num_exons = $ecnt{$chr};
        my $exons = $EXON{$chr};
        for my $exon (@$exons[0..$num_exons-1]) {
            my $x1   = $exon->{Ucount}  || 0;
            my $x2   = $exon->{NUcount} || 0;
            my $s    = $exon->{start};
            my $e    = $exon->{end};
            my $elen = $e - $s + 1;
            print OUTFILE1 "exon\t$chr:$s-$e\t$x1\t$x2\t$elen\n";
        }
    }


}

sub readfile {
    my ($filename, $type, $callback, $exon, $userstrand, $anti, $countsonly) = @_;
    
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
        
        my $num_exons = @{ $exon->{$CHR} ||[]};

        while ($exon->{$CHR}[$indexstart_e{$CHR}]{end} < $start 
               && $indexstart_e{$CHR} <= $num_exons) {
            $indexstart_e{$CHR}++;	
        }

        my $exons = $exon->{$CHR};
        
        for my $span (@$exons[$indexstart_e{$CHR} .. $num_exons - 1]) {

            last if $end < $span->{start};
            if (do_they_overlap([ $span->{ start }, $span->{ end } ],
                                \@flattened_spans) ) {
                $span->{$type}++;
            }
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
                return $B->[$j] == $A->[@$A-1];
            }
        }
        if (($i-1) % 2 == 0) {
            return 1;
        } else {
            $j++;
            if ($j % 2 == 1 && $A->[$i] <= $B->[$j]) {
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

__END__

=head1 NAME

RUM::Script::QuantifyExons

=head1 METHODS

=over 4

=item RUM::Script::QuantifyExons->main

Run the script.

=item readfile

Load the given filename into some internal data structures.

=item do_they_overlap

=back

=head1 AUTHORS

Gregory Grant (ggrant@grant.org)

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012, University of Pennsylvania


