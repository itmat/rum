package RUM::Repository::IndexSpec;

use strict;
no warnings;

use Carp;

=head1 NAME

RUM::Repository::IndexSpec - Represents the specification of a RUM index

=head1 DESCRIPTION

=head2 Parsing from a file

Don't construct a RUM::Repository::IndexSpec directly; use this
B<parse> method to read them from a file.

=over 4

=item RUM::Repository::IndexSpec->parse($file)

Parse the given organisms file and return a list of
RUM::Repository::IndexSpec objects.

=back

=cut

sub parse {
    my ($class, $in) = @_;
    my @orgs;

    while (my $org = _parse_one($in)) {
        push @orgs, $org;
        $org->{order} = scalar(@orgs);
    }
    return @orgs;
}

=head2 Properties

A RUM::Repository::IndexSpec is a simple struct-like object, with the
following properties:

=over

=item $index->latin()

Return the latin name of the organism.

=item $index->common()

Return the common name of the organism.

=item $index->build()

Return the build identifier.

=item $index->urls()

Return an array of the URLs of index files and config file for this
organism.

=item $index->order()

The order that the index appears in in the organisms.txt file,
starting at 1.

=back

=cut

sub latin  {    shift->{latin} }
sub common {    shift->{common} }
sub build  {    shift->{build} }
sub urls   { @{ shift->{urls} } }
sub order  {    shift->{order} }

sub _parse_one {
    my ($in) = @_;

    my $index = bless {}, "RUM::Repository::IndexSpec";
    
    # Matches lines like the following:
    #   -- Homo sapiens [build hg19] (human) start --
    #   -- Homo sapiens [build hg19] (human) end --
    my $re = qr{-- \s+
                (.*) \s+ 
                \[ build \s+ (.*)\] \s+
                \((.*)\) \s+
                (start|end) \s+
                --
           }x;

    my $started = 0;

    while (defined (local $_ = <$in>)) {
        chomp;

        if (my ($latin, $build, $common, $start_or_end) = /$re/g) {

            if ($start_or_end eq 'start') {
                $started = 1;
                $index->{latin} = $latin;
                $index->{build} = $build;
                $index->{common} = $common;
                $index->{urls} = [];
            }
            
            # If we're at the end, add the org we just built up to the list
            if ($start_or_end eq 'end') {
                croak "Saw end tag before start tag" unless $started;
                return $index;
            }
        }

        elsif ($started) {
            push @{ $index->{urls} }, $_;
        }
    }
    
    return;    
}

=head1 AUTHOR

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright University of Pennsylvania, 2012

=cut

1;
