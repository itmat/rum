package RUM::BaseIO;

use strict;
use warnings;
use autodie;

use Carp;

sub new {

    my ($class, %options) = @_;

    my $file = delete $options{-file};
    my $fh   = delete $options{-fh};

    unless ($file xor $fh) {
        croak "$class->new needs either -file or -fh but not both";
    }
    
    open $fh, "<", $file unless $fh;
    my $self = {};
    $self->{file} = $file;
    $self->{fh} = $fh;
    return bless $self, $class;
}

sub aln_iterator {
    my ($self) = @_;
    return RUM::Iterator->iterator(sub { $self->next_aln });
}

1;
