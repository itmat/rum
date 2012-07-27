package RUM::Script::MergeGnuAndTnuAndCnu;

use strict;
use warnings;
use autodie;

use RUM::Usage;
use RUM::RUMIO;

use base 'RUM::Script::Base';

sub main {

    my $self = __PACKAGE__->new;
    $self->get_options(
        "gnu-in=s" => \(my $infile1),
        "tnu-in=s" => \(my $infile2),
        "cnu-in=s" => \(my $infile3),
        "output=s" => \(my $outfile));

    $infile1 or RUM::Usage->bad("Missing --gnu-in option");
    $infile2 or RUM::Usage->bad("Missing --tnu-in option");
    $infile3 or RUM::Usage->bad("Missing --cnu-in option");
    $outfile or RUM::Usage->bad("Missing --output option");

    open my $out, ">", $outfile;

    my @iters;

    # Returns true if the two alignments have the same read id
    # (without direction).
    my $same_read_id = sub { $_[0]->readid_directionless eq
                             $_[1]->readid_directionless };

    for my $filename ($infile1, $infile2, $infile3) {

        # Open an iterator over the alignments in the file
        my $iter = RUM::RUMIO->new(-file => $filename);

        # Now turn that into another iterator that is grouped by read
        # id (without the direction). Each "group" that is returned
        # will be another iterator, so make the iterator over each
        # group peekable.
        my $grouped = $iter->group_by($same_read_id)->imap(
            sub { $_[0]->peekable } );

        # Now make the entire iterator peekable, since we will need to
        # peek at the iterators in order to determine which one has
        # the smallest next value.
        my $peekable = $grouped->peekable;
        push @iters, $peekable;
    }

    my ($gnu, $tnu, $cnu) = @iters;

    # Given an iterator over a group of reads, compares the ids of the
    # first reads in each iterator.
    my $cmp = sub { $_[0]->peek->cmp_read_ids($_[1]->peek) };
    
    # Merge the gnu and tnu iterators together, and then merge that
    # result with the cnu iterator.

    my $append = sub {
        my $iters = shift;
        return $iters->[0] if @{ $iters } == 1;
        return $iters->[0]->append($iters->[1])->peekable;
    };

    my $merged = $gnu->merge(cmp_fn => $cmp, others => [$tnu], group_fn => $append)->peekable->merge(cmp_fn => $cmp, others => [$cnu], group_fn => $append)->peekable;

    while (my $group = $merged->next_val) {
        my %seen;
        my $pairs = $group->group_by(\&RUM::Identifiable::is_mate);

        while (my $pair = $pairs->next_val)  {
            my @lines = $pair->ireduce(sub { $a . $b->raw . "\n" }, "");
            my $lines = "@lines";
            print $out $lines unless $seen{$lines}++;
        }
    }
}

1;

__END__

=head1 NAME

RUM::Script::MergeGuAndTu

=head1 METHODS

=over 4

=item RUM::Script::MergeGuAndTu->main

Run the script.

=back

=head1 AUTHORS

Gregory Grant (ggrant@grant.org)

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012, University of Pennsylvania
