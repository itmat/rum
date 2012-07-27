package RUM::Script::MergeSamHeaders;

use strict;
no warnings;
use Carp;
use RUM::Sort qw(by_chromosome);

use base 'RUM::Script::Base';

sub main {
    my $self = __PACKAGE__->new;
    $self->get_options("name=s" => \(my $name = "unknown"));

    local $_;
    my %header;
    for my $filename (@ARGV) {
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

__END__

=head1 NAME

RUM::Script::MergeSamHeaders

=head1 METHODS

=over 4

=item RUM::Script::MergeSamHeaders->main

Run the script.

=back

=head1 AUTHORS

Gregory Grant (ggrant@grant.org)

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012, University of Pennsylvania


