package RUM::BlatIO;

use strict;
use warnings;

use base 'RUM::AlignIO';

use Data::Dumper;

use RUM::Logging;

use Carp;

our $log = RUM::Logging->get_logger;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(%options);
    $self->_read_headers;
    return $self;
}

sub join_headers {
    my ($self, @lines) = @_;

    my @trimmed;

    my $joined = '';

    my $join_char = ' ';

  LINE: for my $line (@lines) {
        next LINE unless defined $line;

        $line =~ s/^\s*//;
        $line =~ s/\s*$//;

        next LINE unless $line;

        if (!$joined) {
            $joined = $line;
        }
        elsif ($joined =~ s/-$//) {
            $joined .= $line;
        }
        else {
            $joined .= ' ' . $line;
        }
    }

    return $joined;
}

# Given a filehandle, skip over all rows that appear to be header
# rows. After I return, the filehandle will be positioned at the first
# data row.
sub _read_headers {
    my ($self) = @_;

    my $fh = $self->filehandle;

    my $ps_layout = <$fh> || '';
    die "Expected 'psLayout' on line 1 of blat output" unless $ps_layout =~ /psLayout/;

    my $blank = <$fh>;

    my $header1 = <$fh>;
    my $header2 = <$fh>;

    my @header1 = split /\t/, $header1;
    my @header2 = split /\t/, $header2;
    
    my @fields = map { $self->join_headers($header1[$_], $header2[$_]) } (0 .. $#header1);

    $self->{fields} = \@fields;
    
    warn "My fields are " . Dumper(\@fields);
}


sub fields { shift->{fields} }
