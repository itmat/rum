package RUM::SeqIO;

use strict;
use warnings;
use autodie;

use Carp;
use RUM::Sequence;

use base 'RUM::BaseIO';

sub next_rec {
    return shift->next_seq;
}

sub next_seq {

    my ($self) = @_;
    my $fh = $self->filehandle;
    my $header = <$fh>;
    return unless defined $header;

    chomp $header;

    my $seq = <$fh>;

  LINE: while (1) {
        my $pos = tell $fh;
        my $line = <$fh>;
        last LINE if ! $line;
        if ($line =~ /^>/) {
            seek $fh, $pos, 0;
            last LINE;
        }
        else {
            chomp $line;
            $seq .= $line;
        }
        
    }

    return RUM::Sequence->new(
        readid => substr($header, 1),
        seq    => $seq);
}

sub write_seq {
    my ($self, $seq) = @_;
    my $fh = $self->filehandle;
    printf $fh ">%s\n%s\n", $seq->readid, $seq->seq;
}

1;
