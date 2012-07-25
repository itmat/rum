package RUM::BlatIO;

use strict;
use warnings;

use Carp;
use Data::Dumper;

use RUM::Logging;
use RUM::BlatAlignment;

use base 'RUM::AlignIO';

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

    my $ps_layout = <$fh>; chomp $ps_layout;
    croak "Expected 'psLayout' on line 1 of blat output; got $ps_layout" unless $ps_layout =~ /psLayout/;

    my $blank   = <$fh>; chomp $blank;
    my $header1 = <$fh>; chomp $header1;
    my $header2 = <$fh>; chomp $header2;
    my $hr      = <$fh>; chomp $hr;

    my @header1 = split /\t/, $header1;
    my @header2 = split /\t/, $header2;
    
    my @fields = map { $self->join_headers($header1[$_], $header2[$_]) } (0 .. $#header1);

    $self->{header_lines} = [$ps_layout, $blank, $header1, $header2, $hr];

    $self->{fields} = \@fields;
    
}


sub parse_aln {
    my ($self, $line) = @_;
    my @vals = split /\t/, $line;
    my %rec;
    
    for my $i ( 0 .. $#vals) {
        $rec{$self->fields->[$i]} = $vals[$i];
    }
    
    return RUM::BlatAlignment->new(
        readid => $rec{'Q name'},
        chr    => $rec{'T name'},
        strand => $rec{'strand'},
        seq    => '',
        raw => $line,
        mismatch => $rec{'mismatch'},
        q_gap_count => $rec{'Q gap count'},
        q_name => $rec{'Q name'},
        q_size => $rec{'Q size'},
        q_start => $rec{'Q start'},
        q_end   => $rec{'Q end'},
        t_name  => $rec{'T name'},
    );
}


sub fields { shift->{fields} }

sub header_lines { shift->{header_lines} }
