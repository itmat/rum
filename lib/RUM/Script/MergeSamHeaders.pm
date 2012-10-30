package RUM::Script::MergeSamHeaders;

use strict;
no warnings;
use Carp;
use RUM::Sort qw(by_chromosome);

use base 'RUM::Script::Base';

our $log = RUM::Logging->get_logger();

sub summary {
    'Merge together the SAM header files listed on the command line and
print the merged headers to stdout'
}

sub accepted_options {
    return (
        RUM::Property->new(
            opt => 'name=s',
            desc => 'Name',
            default => 'unknown'
        ),
        RUM::Property->new(
            opt => 'sam_header',
            desc => 'Sam header file',
            positional => 1,
            nargs => '+',
            required => 1),
    );
}

sub run {
    my ($self) = @_;

    my $props = $self->properties;
    my $name  = $props->get('name');

    local $_;
    my %header;
    for my $filename (@{ $props->get('sam_header') }) {
        open my $in, "<", $filename;
        while (defined($_ = <$in>)) {
            chomp;
            /SN:([^\s]+)\s/ or croak "Bad SAM header $_";
            $header{$1}=$_;
        }
    }
    for (sort by_chromosome keys %header) {
        print "$header{$_}\n";
    }

    print join("\t", '@RG', "ID:$name", "SM:$name"), "\n";
}


1;
