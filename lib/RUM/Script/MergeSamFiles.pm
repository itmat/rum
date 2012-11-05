package RUM::Script::MergeSamFiles;

use strict;
use warnings;
use autodie;

use base 'RUM::Script::Base';

sub accepted_options {
    return (
        RUM::Property->new(
            opt => 'headers',
            desc => 'File containing merged headers',
            positional => 1,
            required => 1),
        RUM::Property->new(
            opt => 'input',
            desc => 'Input SAM file',
            positional => 1,
            required => 1,
            nargs => '+')
      );
}

sub summary {
    "Merge SAM files together"
}

sub reader {
    my ($filename) = @_;
    open my $in, '<', $filename;
    my $line = <$in>;
    return sub {

        return if ! defined $line;

        my @lines = ($line);

        my ($this_readid, undef) = split /\t/, $line;
        while (defined($line = <$in>)) {
            my ($readid, undef) = split /\t/, $line;
            if ($readid eq $this_readid) {
                push @lines, $line;
            }
            else {
                return \@lines;
            }
        }
        return \@lines;
    };
}

sub run {
    my ($self) = @_;
    my $props = $self->properties;

    open my $header_fh, '<', $props->get('headers');
    while (defined(my $header_line = <$header_fh>)) {
        print $header_line;
    }

    my @files = @{ $props->get('input') };
    my @readers = map { reader($_) } @files;

    my $n = @files;
    my $i = $#readers;
    while (@readers) {
        $i = ($i + 1) % @readers;
        my $reader = $readers[$i];
        my $lines = $reader->();
        if ($lines) {
            for my $line (@{ $lines }) {
                print $line;
            }
        }
        else {
            splice @readers, $i, 1;
        }
    }
}

1;
