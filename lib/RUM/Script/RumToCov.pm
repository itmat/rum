package RUM::Script::RumToCov;

use strict;
use warnings;
use autodie;

use RUM::UsageErrors;
use Getopt::Long;

use base 'RUM::Script::Base';

sub run {
    
    my ($self) = @_;
    
    open my $in_fh,  '<', $self->{in_filename};
    open my $out_fh, '>', $self->{out_filename};
    my $name = $self->{name};

    print $out_fh qq{track type=bedGraph name="$name" description="$name" visibility=full color=255,0,0 priority=10\n};

    my $footprint = 0;
    
    my $last_chr = '';

  LINE: while (1) {

        my @spans;
        my $chr = '';

        # Read a line from the input and parse out the chromosome and
        # spans.
        if (defined(my $line = <$in_fh>)) {
            chomp($line);
            (my $readid, $chr, my $spans, my $strand) = split /\t/, $line;    

            # Spans look like "start-end[, start-end]...
            @spans = map { [split /-/] } split /, /, $spans;

            # Create spans as a list of records of the format [ start,
            # end, coverage ], representing a span where elements from
            # start to end - 1 have the specified coverage. Since we
            # are just processing one read, the coverage for each span
            # is initially 1.
            @spans = map { [ $_->[0] - 1, $_->[1], 1 ] } @spans;
        }

        # If we just finished a chromosome, print out the coverage
        if ($chr ne $last_chr) {
            if ($last_chr) {
                $self->logger->debug("Printing coverage for chromosome $last_chr\n");
            }
          COVERAGE: for my $rec (@{ $self->purge_spans() }) {
                my ($start, $end, $cov) = @{ $rec };
                
                # We will end up representing gaps with no coverage as
                # a span with zero coverage. We don't want to print
                # anything for these lines.
                next COVERAGE if ! $cov;

                print $out_fh join("\t", $last_chr, $start, $end, $cov), "\n";
                $footprint += $end - $start;
            }
            if ($chr) {
                $self->logger->debug("Calculating coverage for $chr\n");
            }
            $last_chr = $chr;
        }

        last LINE unless @spans;

        $self->add_spans(\@spans);
    }

    if (my $statsfile = $self->{stats_filename}) {
        open my $stats_out, '>', $statsfile;
        print $stats_out "footprint for $self->{in_filename} : $footprint\n";
    }

}

sub main {

    my $self = __PACKAGE__->new;

    $self->get_options(
        "output|o=s" => \($self->{out_filename}   = undef),
        "stats=s"    => \($self->{stats_filename} = undef),
        "name=s"     => \($self->{name}           = undef));

    my $errors = RUM::UsageErrors->new;

    $self->{out_filename} or $errors->add(
        "Please specify an output file with -o or --output");

    $self->{in_filename} = $ARGV[0] or $errors->add(
        "Please provide an input file on the command line");

    $errors->check;

    $self->{name} ||= $self->{in_filename} . " Coverage";

    $self->logger->info("Making coverage plot $self->{out_filename}...");
    $self->run;
}

sub add_spans {
    my ($self, $spans) = @_;

    my $delta_for_pos = $self->{delta_for_pos} ||= {};

    # Each span is an array of [ start pos, end pos, coverage ].
    # Translate the spans into an array of events, where each event
    # has a position and a coverage delta. For example the span [ 5,
    # 8, 2 ] translates to [ [5, 2], [8, -2] ], meaning that at
    # position 5 we increase coverage by 2 and at position 8 we
    # decrease coverage by 2.

    for my $span (@{ $spans }) {
        my ($start, $end, $cov) = @{ $span };
        $delta_for_pos->{$start}  += $cov;
        $delta_for_pos->{$end}    -= $cov;
    }
}

sub purge_spans {
    my ($self, $limit) = @_;

    my ($last_pos, $last_cov);
    my $delta_for_pos = $self->{delta_for_pos} ||= {};
    my @result;
    for my $pos (sort { $a <=> $b } keys %{ $delta_for_pos }) {
        my $cov_delta = $delta_for_pos->{$pos};
        next if ! $cov_delta;
        if (defined($last_pos)) {
            push @result, [ $last_pos, $pos, $last_cov ];
        }
        $last_pos = $pos;
        $last_cov += $cov_delta;
    }
    $self->{delta_for_pos} = {};
    return \@result;
}

1;

=head1 NAME

RUM::Script::RumToCov - Calculate coverage

=head1 METHODS

=over 4

=item $rum2cov->main

Main method, call without args

=item $rum2cov->run

Read in the RUM_* files and calculate coverage. Call after command
line args are set.

=item $rum2cov->add_spans($spans)

$spans must be an array ref of array refs, where each array ref is of
the format [ start, end, coverage ]. Adds the spans to an internal
data structure used to track coverage.

=item $rum2cov->purge_spans($spans)

Clear the internal coverage data structure and return the accumulated
coverage counts for all the spans, in the same format as the $spans
argument to add_spans.

=back

1;

