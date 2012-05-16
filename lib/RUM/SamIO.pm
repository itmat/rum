package RUM::SamIO;

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

sub new {
    my ($class, %options) = @_;
    my $self = {};
    $self->{-fh} = delete $options{-fh} or croak
        "$class->new needs a -fh option";
    return bless $self, $class;
}

