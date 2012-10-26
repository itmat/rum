package RUM::Script::MergeChrCounts;

use strict;
no warnings;

use RUM::Logging;
use RUM::Common qw(read_chunk_id_mapping);
use RUM::Sort qw(by_chromosome);
our $log = RUM::Logging->get_logger();

use base 'RUM::Script::Base';

sub summary {
    'Merge two or more chr counts files'
}

sub accepted_options {
    return (
        RUM::Property->new(
            opt => 'output|o=s',
            desc => 'Output file',
            required => 1),
        RUM::Property->new(
            opt => 'input',
            desc => 'Input file',
            positional => 1,
            required => 1,
            nargs => '+'));
}

sub run {

    my ($self) = @_;
    my $props = $self->properties;

    my $outfile = $props->get('output');
    my @file = @{ $props->get('input') };

    open(OUTFILE, ">>", $outfile) or die "Can't open $outfile for appending";

    my %chrcnt;
    for my $filename (@file) {
        open(INFILE, $filename) or die "Can't open $filename for reading: $!";
        local $_ = <INFILE>;
        $_ = <INFILE>;
        $_ = <INFILE>;
        $_ = <INFILE>;
        while (defined ($_ = <INFILE>)) {
            chomp;
            my @a1 = split /\t/;
            $chrcnt{$a1[0]} = $chrcnt{$a1[0]} + $a1[1];
        }
        close(INFILE);
    }

    for my $chr (sort by_chromosome keys %chrcnt) {
        my $cnt = $chrcnt{$chr};
        print OUTFILE "$chr\t$cnt\n";
    }
}

    1;
