package RUM::SamIO;

=head1 NAME

RUM::SamIO - Interface for writing SAM files

=head1 METHODS

=over 4

=cut

use strict;
use warnings;

use Carp;
use Exporter 'import';

our @FLAGS = qw($FLAG_MULTIPLE_SEGMENTS
                 $FLAG_BOTH_SEGMENTS_ALIGNED
                 $FLAG_SEGMENT_UNMAPPED
                 $FLAG_NEXT_SEGMENT_UNMAPPED
                 $FLAG_SEGMENT_REVERSE_COMPLEMENTED
                 $FLAG_NEXT_SEGMENT_REVERSED
                 $FLAG_FIRST_SEGMENT
                 $FLAG_LAST_SEGMENT
                 $FLAG_SECONDARY_ALIGNMENT
                 $FLAG_NOT_PASSING_QC
                 $FLAG_DUPLICATE);

our @EXPORT_OK = @FLAGS;
our %EXPORT_TAGS = (flags => \@FLAGS);

our $FLAG_MULTIPLE_SEGMENTS             = 0x1;
our $FLAG_BOTH_SEGMENTS_ALIGNED         = 0x2;
our $FLAG_SEGMENT_UNMAPPED              = 0x4;
our $FLAG_NEXT_SEGMENT_UNMAPPED         = 0x8;
our $FLAG_SEGMENT_REVERSE_COMPLEMENTED  = 0x10;
our $FLAG_NEXT_SEGMENT_REVERSED         = 0x20;
our $FLAG_FIRST_SEGMENT                 = 0x40;
our $FLAG_LAST_SEGMENT                  = 0x80;
our $FLAG_SECONDARY_ALIGNMENT           = 0x100;
our $FLAG_NOT_PASSING_QC                = 0x200;
our $FLAG_DUPLICATE                     = 0x400;


our @DESCRIPTIONS = (
    "template having multiple segments in sequencing",
    "each segment properly aligned according to the aligner",
    "segment unmapped",
    "next segment in the template unmapped",
    "SEQ being reverse complemented",
    "SEQ of the next segment in the template being reversed",
    "the first segment in the template",
    "the last segment in the template",
    "secondary alignment",
    "not passing quality controls",
    "PCR or optical duplicate"
);

=item RUM::SamIO->flag_descriptions($flag)

Return an array ref of the string descriptions of the bits that are
set in the given flag.

=cut

sub flag_descriptions {
    my ($class, $flag) = @_;

    my @result;

    for my $i (0 .. $#DESCRIPTIONS) {
        if ($flag & (1 << $i)) {
            push @result, $DESCRIPTIONS[$i];
        }
    }
    return \@result;
}

=item RUM::SamIO->fix_flag($flag)

If the flag is internally inconsistent according to the SAM format
specification, return a fixed version of it.

=cut

sub fix_flag {
    my ($class, $flag, $callback) = @_;
    # Bit 0x4 is the only reliable place to tell whether the segment
    # is unmapped. If 0x4 is set, no assumptions can be made about
    # RNAME, POS, CIGAR, MAPQ, bits 0x2, 0x10 and 0x100 and the bit
    # 0x20 of the next segment in the template.
    if ($flag & 0x4) {
        my $mask = 0x2 | 0x10 | 0x100;
        if (my $bad = $flag | $mask) {
            for my $desc (@{ $class->flag_descriptions($bad) }) {
                $callback->($bad, "unset");
            }
            $flag = $flag & ~$mask;
        }
    }

    # If 0x1 is unset, no assumptions can be made about 0x2, 0x8,
    # 0x20, 0x40 and 0x80.
    unless ($flag & 0x1) {
        my $mask = 0x2 | 0x8 | 0x20 | 0x40 | 0x80;
        if (my $bad = $flag | $mask) {
            for my $desc (@{ $class->flag_descriptions($bad) }) {
                $callback->($bad, "unset");
            }
            $flag = $flag & ~$mask;
        }
    }
}

=back

=head1 CONSTRUCTORS

=over 4

=item RUM::SamIO->new(-fh => $filehandle)

Return a new RUM::SamIO that writes to the given filehandle.

=cut

sub new {
    my ($class, %options) = @_;
    my $self = {};
    $self->{-fh} = delete $options{-fh} or croak
        "$class->new needs a -fh option";
    return bless $self, $class;
}

=back

=head1 OBJECT METHODS

=over 4

=item $sam->write_rec($record)

Write the given record to the output file.

=cut

sub write_rec {
    my $self = shift;
    my $rec = shift or croak '$sam->write_rec needs a record';
    my $fh = $self->{-fh};
    if (@$rec < 11) {
        croak "Not enough fields for SAM file in @$rec";
    }
    no warnings;
    my $line = join("\t", @$rec) . "\n";

    print $fh $line;
}

