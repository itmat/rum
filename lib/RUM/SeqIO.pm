package RUM::SeqIO;

use strict;
use warnings;
use autodie;

use Carp;
use RUM::Sequence;

use base 'RUM::BaseIO';

sub new {
    my ($class, %params) = @_;
    my $fmt = delete $params{fmt} || 'fasta';
    my $self = $class->SUPER::new(%params);
    $self->{fmt} = $fmt;
    return $self;
}

sub next_rec {
    return shift->next_seq;
}

sub next_seq {

    my ($self) = @_;
    my $fh = $self->filehandle;
    my $header = <$fh>;
    return unless defined $header;
    chomp $header;

    my $seq = '';
    my $qual;

    if ($self->{fmt} eq 'fasta')  {
      LINE: while (1) {
            my $pos = tell $fh;
            my $line = <$fh>;
            last LINE if ! defined $line;
            chomp $line;
            if ($line =~ /^>/) {
                seek $fh, $pos, 0;
                last LINE;
            }
            else {
                $seq .= $line;
            }
        }
    }
    
    elsif ($self->{fmt} eq 'fastq') {
        chomp($seq = <$fh>);
        <$fh>;
        chomp($qual = <$fh>);
    }

    return RUM::Sequence->new(
        readid => substr($header, 1),
        seq    => $seq,
        qual   => $qual);
}

sub write_seq {
    my ($self, $seq) = @_;
    my $fh = $self->filehandle;
    printf $fh ">%s\n%s\n", $seq->readid, $seq->seq;
}

sub write_qual_as_seq {
    my ($self, $rec)  = @_;
    my $fh = $self->filehandle;
    printf $fh ">%s\n%s\n", $rec->readid, $rec->seq;
}

1;
