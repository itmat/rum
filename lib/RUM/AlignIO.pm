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

1;
