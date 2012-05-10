package RUM::AlignIO;

use strict;
use warnings;
use autodie;

use Carp;

use RUM::Alignment;

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

sub next_aln {
    my ($self) = @_;
    
    my $fh = $self->{fh};
    local $_ = <$fh>;

    defined or return;
    chomp;
    my ($readid, $chr, $locs, $strand, $seq) = split /\t/;
    
    my @locs = map { [split /-/] } split /,\s*/, $locs;

    return RUM::Alignment->new(-readid => $readid,
                               -chr => $chr,
                               -locs => \@locs,
                               -strand => $strand,
                               -seq => $seq);
}

sub write_aln {
    my ($self, $aln) = @_;
    my $fh = $self->{fh};
    my ($readid, $chr, $locs, $strand, $seq) = 
        @$aln{qw(readid chr locs strand seq)};
    $locs = join(", ", map("$_->[0]-$_->[1]", @$locs));
    print $fh join("\t", $readid, $chr, $locs, $strand, $seq), "\n";
}

1;
