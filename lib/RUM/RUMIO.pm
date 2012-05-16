package RUM::RUMIO;

use strict;
use warnings;

use base 'RUM::AlignIO';

sub parse_aln {
    my $self = shift;
    local $_ = shift;

    my ($readid, $chr, $locs, $strand, $seq) = split /\t/;
    
    my @locs = map { [split /-/] } split /,\s*/, $locs;

    return RUM::Alignment->new(-readid => $readid,
                               -chr => $chr,
                               -locs => \@locs,
                               -strand => $strand,
                               -seq => $seq);
}

sub format_aln {
    my ($self, $aln) = @_;
    my ($readid, $chr, $locs, $strand, $seq) = 
        @$aln{qw(readid chr locs strand seq)};
    $locs = join(", ", map("$_->[0]-$_->[1]", @$locs));
    return join("\t", $readid, $chr, $locs, $strand, $seq);
}

sub validate_aln {
    my ($self, $aln) = @_;

    my $aln = $rumio->peek;
    
    $ok &&= $aln->readid =~ /^seq.\d+[ab]?/;
    $ok &&= ref($aln->locs) =~ /^ARRAY/;
    $ok &&= $ref->strand =~ /^(\+|-)$/;
    $ok &&= $ref->seq =~ /^[ACGTN:+]+$/;
    
    $ok or die join(
        " ",
        "The first line of the file '$rum_unique_file' is misformatted,",
        "it does not look like a RUM output file.");
}

1;
