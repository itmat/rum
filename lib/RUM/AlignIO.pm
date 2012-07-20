package RUM::AlignIO;

use strict;
use warnings;
use autodie;
use Scalar::Util qw(blessed);
use Carp;

use RUM::Alignment;

use base 'RUM::BaseIO';

sub next_rec {
    return shift->next_aln;
}

sub next_aln {
    my ($self) = @_;
    my $fh = $self->filehandle;
    my $line = <$fh>;
    return unless defined $line;
    chomp $line;
    return $self->parse_aln($line);
}

sub write_aln {
    my ($self, $aln) = @_;
    my $fh = $self->filehandle;
    print $fh $self->format_aln($aln), "\n";
}

sub parse_aln { croak "Not implemented" }

sub write_alns {
    my ($self, $iter) = @_;

    if (ref($iter) =~ /^ARRAY/) {
        for my $aln (@{ $iter }) {
            $self->write_aln($aln);            
        }
    }
    elsif (blessed($iter) && $iter->isa('RUM::Mapper')) {
        $self->write_alns($iter->alignments);
    }
    else {
        while (my $aln = $iter->next_val) {
            $self->write_aln($aln);
        }
    }
}

sub longest_read {

    my ($self) = @_;
    my $count = 0;
    my $readlength = 0;
    while (my $aln = $self->next_val) {
        my $length = 0;
        my $locs = $aln->locs;
        
        $count++;
        for my $span ( @{ $locs } ) {
            my ($start, $end) = @{ $span };
            $length += $end - $start + 1;
        }
        if ($length > $readlength) {
            $readlength = $length;
            $count = 0;
        }
        if ($count > 50000) { 
            # it checked 50,000 lines without finding anything
            # larger than the last time readlength was
            # changed, so it's most certainly found the max.
            # Went through this to avoid the user having to
            # input the readlength.
            last;
        }
    }
    return $readlength;
}

sub to_mapper_iter {
    my ($self, $source) = @_;

    return $self->group_by(
        sub { 
            my ($x, $y) = @_;
            return RUM::Identifiable::is_mate($x, $y),
        },
        sub { 
            my $alns = shift;
            RUM::Mapper->new(alignments => $alns,
                             source => $source) 
          }
    )->peekable;
}




1;
