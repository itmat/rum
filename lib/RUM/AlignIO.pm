package RUM::AlignIO;

use strict;
use warnings;
use autodie;

use Carp;

use RUM::Alignment;

use base 'RUM::BaseIO';

sub next_rec {
    my ($self) = @_;
    my $fh = $self->filehandle;
    local $_ = <$fh>;
    defined or return;
    chomp;
    return $self->parse_aln($_);            
}

sub next_aln {
    $_[0]->();
}

sub write_aln {
    my ($self, $aln) = @_;
    my $fh = $self->filehandle;
    print $fh $self->format_aln($aln), "\n";
}

sub parse_aln { croak "Not implemented" }

1;
