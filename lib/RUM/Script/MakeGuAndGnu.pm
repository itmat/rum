package RUM::Script::MakeGuAndGnu;

use strict;
no warnings;
use autodie;

use RUM::Usage;
use RUM::Logging;
use RUM::BowtieIO;
use RUM::Iterator;
use Getopt::Long;
use Carp;

our $log = RUM::Logging->get_logger();

sub same_or_mate {
    my ($x, $y) = @_;
    return $x->is_same_read($y) || $x->is_mate($y);
}

sub write_aln {
    my ($fh, $read) = @_;

    my @fields = (
        $read->readid,
        $read->chromosome,
        $read->locs->[0][0] . "-" . $read->locs->[0][1],
        $read->seq,
        $read->strand
    );
    print $fh join("\t", @fields), "\n";
}


sub new {
    my ($class, %options) = @_;

    my $self = {};

    my @fields = qw(in gu gnu paired max_pair_dist);

    for my $key (@fields) {
        $self->{$key} = delete $options{$key};
    }
    bless $self, $class;
}

sub main {

    print "Argv is @ARGV\n";

    GetOptions(
        "unique=s"        => \(my $outfile1),
        "non-unique=s"    => \(my $outfile2),
        "paired"          => \(my $paired),
        "single"          => \(my $single),
        "max-pair-dist=s" => \(my $max_pair_dist = 500000),
        "help|h"          => sub { RUM::Usage->help },
        "verbose|v"       => sub { $log->more_logging(1) },
        "quiet|q"         => sub { $log->less_logging(1) });

    @ARGV == 1 or RUM::Usage->bad(
        "Please specify an input file");
    
    $outfile1 or RUM::Usage->bad(
        "Please specify output file for unique mappers with --unique");

    $outfile2 or RUM::Usage->bad(
        "Please specify output file for non-unique mappers with --non-unique");

    ($single xor $paired) or RUM::Usage->bad(
        "Please specify exactly one type with either --single or --paired");

    open my $gu,  ">", $outfile1;
    open my $gnu, ">", $outfile2;

    my $self = __PACKAGE__->new(
        in => $ARGV[0],
        gu => $gu,
        gnu => $gnu,
        paired => $paired,
        max_pair_dist => $max_pair_dist
    );
    $self->run();
}



sub clean_alignment {
    my ($class, $aln) = @_;
    
    local $_   = $aln->seq;
    my $start  = $aln->loc + 1;
    my $chr    = $aln->chromosome;
    return undef if /^N+$/;
        
    $chr =~ s/:.*//;
    s/^(N+)// and $start += + length($1);
    s/N+$//;
    my $end = $start + length() - 1; 
    
    my $aln = RUM::Alignment->new(
        readid => $aln->readid,
        strand => $aln->strand,
        chr    => $aln->chromosome,
        locs   => [[$start, $end]],
        seq    => $_);
    
}

sub split_forward_and_reverse {
    my ($class, $group) = @_;
    my %fwd;
    my %rev;

    my @cleaned = map { $class->clean_alignment($_) } @{ $group };
    @cleaned = grep { $_ } @cleaned;

    my $i;
    for my $aln (@cleaned) {
        my $hash = $aln->is_forward ? \%fwd : \%rev;
        $hash->{key($aln)} ||= $aln;
    }
    return ([values(%fwd)], [values(%rev)]);
}

sub key {

    if (@_ == 1) {
        my $aln = shift;
        my ($start, $end) = @{ $aln->locs->[0] };
        join("\t", $aln->readid, $aln->strand,
             $aln->chromosome, $start, $end, $aln->seq);
    }
    elsif (@_ == 2) {
        my ($f, $r) = @_;
        
        return sprintf(
            "%s\t%s\t%d-%d\t%s\t%s\t\n%s\t%s\t%d-%d\t%s\t%s\t\n",
            $f->readid, $f->chromosome, @{ $f->locs->[0] }, $f->seq, $f->strand,
            $r->readid, $r->chromosome, @{ $r->locs->[0] }, $r->seq, $r->strand);
    }
}


sub handle_group {
    
    my ($self, $group) = @_;
    
    my ($fwd, $rev) = $self->split_forward_and_reverse($group);

    my $n_fwd = @{ $fwd };
    my $n_rev = @{ $rev };

    my $max_pair_dist = $self->{max_pair_dist};
    my $paired        = $self->{paired};

    # NOTE: the following three if's cover all cases we care
    # about, because if numa > 1 and numb = 0, then that's not
    # really ambiguous, blat might resolve it

    if ($n_fwd + $n_rev == 1) { # unique forward match, no reverse
        my @reads = (@$fwd, @$rev);
        my $read = $reads[0];

        # If this is the reverse read, reverse it, because we are
        # reporting strand of forward in all cases
        if ($read->is_reverse) {
            my $strand = $read->strand eq '+' ? '-' : '+';
            $read = $read->copy(strand => $strand);
        }
        return [$read];
    }
    
    elsif (!$paired) {
        return $fwd;
    }

    return [] unless $n_fwd && $n_rev && ($n_fwd * $n_rev < 1000000);
        
    # forward and reverse matches, must check for consistency,
    # but not if more than 1,000,000 possibilities, in that
    # case skip...
    my %consistent_mappers;
    for my $aread (@$fwd) {

        my $aid = $aread->readid;
        my $astrand = $aread->strand;
        my $achr = $aread->chromosome;
        my ($astart, $aend) = @{ $aread->locs->[0] };
        my $aseq = $aread->seq;
#        print "Fwd start is $astart\n";            
        for my $bread (@$rev) {

            my $bid = $bread->readid;
            my $bstrand = $bread->strand;
            my $bchr = $bread->chromosome;
            my ($bstart, $bend) = @{ $bread->locs->[0] };
            my $bseq = $bread->seq;
#            print "  Rev start is $bstart\n";            
                
            next unless $achr eq $bchr;
#            print "  Still here, strands are $astrand, $bstrand\n";
            if ($astrand eq "+" && 
                $bstrand eq '-' &&
                $astart <= $bstart && 
                $bstart - $astart < $max_pair_dist) {
                
#                print "    Adding it\n";
                
                if ($bstart > $aend + 1) {
                    my $new_bread = $bread->copy(strand => $astrand);

                    $consistent_mappers{key($aread, $new_bread)} = [$aread, $new_bread];
                } else {
                    my $overlap = $aend - $bstart + 1;
                    my @sq = split(//,$bseq);
                    my $joined_seq = $aseq;
                    for (my $i=$overlap; $i<@sq; $i++) {
                        $joined_seq = $joined_seq . $sq[$i];
                    }
                    $aid =~ s/a//;
                    
                    my $aln = RUM::Alignment->new(
                        readid => $aid,
                        chr => $achr,
                        locs => [$bend > $aend ? [$astart, $bend] : [$astart, $aend]],
                        seq => $joined_seq,
                        strand => $astrand
                    );
                    
                    $consistent_mappers{key($aln)} = $aln;
                }
            }
            elsif ($astrand eq "-" &&
                   $bstrand eq '+' &&
                   $bstart <= $astart && 
                   $astart - $bstart < $max_pair_dist) {
#                printf "    Adding $astart and $bstart: %d\n", $astart - $bstart;
                if ($astart > $bend + 1) {
                    my $new_bread = $bread->copy(strand => $astrand);
                    $consistent_mappers{key($aread, $new_bread)} = [$aread, $new_bread];
                } else {
                    my $overlap = $bend - $astart + 1;
                    my @sq = split(//,$bseq);
                    my $seq = substr($bseq, 0, length($bseq) - $overlap) . $aseq;
                    $aid =~ s/a//;
                    
                    my $aln = RUM::Alignment->new(
                        readid => $aid,
                        chr => $achr,
                        locs => [$bstart <= $astart ? [$bstart, $aend] : [$astart, $aend]],
                        seq => $seq,
                        strand => $astrand
                    );
                    $consistent_mappers{key($aln)} = $aln;
                }
            }
        }
    }

#    print "\nConsistent mappers:\n" . join("\n", keys %consistent_mappers);

    return [values %consistent_mappers];
}


sub run {
    my ($self) = @_;

    my $gu = $self->{gu};
    my $gnu = $self->{gnu};
    my $in = $self->{in};
    my $bowtie_in = RUM::BowtieIO->new(-file => $in);
    my $it = $bowtie_in->aln_iterator->group_by(\&same_or_mate);

    while (my $group = $it->()) {
        my $mappers = $self->handle_group($group->to_array);
        my $fh = @$mappers == 1 ? $gu : $gnu;
        for my $aln (@$mappers) {
            my @reads = ref($aln) =~ /^ARRAY/ ? @{ $aln } : $aln;
            for my $read (@reads) {
                write_aln $fh, $read;
            }
        }
    }

}

1;
