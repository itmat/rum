package RUM::Script::RumToCov;

use strict;
use warnings;
use autodie;

use RUM::UsageErrors;
use Getopt::Long;
use File::Temp;

use base 'RUM::Script::Base';

sub run {
    
    my ($self) = @_;
    
    open my $in_fh,  '<', $self->{in_filename};
    open my $out_fh, '>', $self->{out_filename};
    my $name = $self->{name};

    print $out_fh qq{track type=bedGraph name="$name" description="$name" visibility=full color=255,0,0 priority=10\n};

    my $footprint = 0;
    
    my $last_chr = '';

    my $count = 0;

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

            my $printer = sub {
                my ($start, $end, $cov) = @_;
                if ($cov) {
                    print $out_fh join("\t", $last_chr, $start, $end, $cov), "\n";
                    $footprint += $end - $start;
                }
            };

            $self->purge_spans($printer);
#          COVERAGE: for my $rec (@{ $self->purge_spans() }) {
#                my ($start, $end, $cov) = @{ $rec };
                
                # We will end up representing gaps with no coverage as
                # a span with zero coverage. We don't want to print
                # anything for these lines.
#                next COVERAGE if ! $cov;

#                print $out_fh join("\t", $last_chr, $start, $end, $cov), "\n";
#                $footprint += $end - $start;
#            }
            if ($chr) {
                $self->logger->debug("Calculating coverage for $chr\n");
            }
            $last_chr = $chr;
        }

        last LINE unless @spans;

        $self->add_spans(\@spans);
        if ((++$count % 100000) == 0) {
            $self->logger->debug("Read $count lines, at $spans[0][0]");
        }
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

    if (!$self->{temp_fh}) {
        $self->{temp_fh} = File::Temp->new;
        $self->logger->debug("Writing to $self->{temp_fh}");
    }
    my $fh = $self->{temp_fh};

    # Each span is an array of [ start pos, end pos, coverage ].
    # Translate the spans into an array of events, where each event
    # has a position and a coverage delta. For example the span [ 5,
    # 8, 2 ] translates to [ [5, 2], [8, -2] ], meaning that at
    # position 5 we increase coverage by 2 and at position 8 we
    # decrease coverage by 2.

    for my $span (@{ $spans }) {
        my ($start, $end, $cov_up) = @{ $span };
        my $cov_down = 0 - $cov_up;
        print $fh "$start\t$cov_up\n";
        print $fh "$end\t$cov_down\n";
    }
}

sub group_events {
    my ($fh) = @_;

    my $pos;
    my $cov;

    return sub {
        my $result;
        while (defined(my $line = <$fh>)) {
            chomp $line;

            my ($new_pos, $cov_change) = split /\t/, $line;

            if (!defined($pos)) {
                $pos = $new_pos;
                $cov = $cov_change;
            }
            elsif ($pos == $new_pos) {
                $cov += $cov_change;
            }
            else {
                $result = [$pos, $cov];
                $pos = $new_pos;
                $cov = $cov_change;
                return $result if $result->[1];
            }
        }
        if (defined($pos)) {
            my $result = [ $pos, $cov ];
            undef $pos;
            undef $cov;
            return $result;
        }
        return;
    };
}

sub purge_spans {
    my ($self, $callback) = @_;
    
    if (my $fh = delete $self->{temp_fh}) {
        close $fh;

        my $cov = 0;

        my ($p, $q);
        my $last_cov = 0;

        open my $sorted, '-|', "sort -n $fh";
        my $iter = group_events($sorted);
        my $last_pos;
      EVENT: while (defined (my $rec = $iter->())) {
            my ($pos, $cov_change) = @{ $rec };

            if (defined ($last_pos)) {
                $callback->($last_pos, $pos, $cov);
            }
            $cov += $cov_change;
            $last_pos = $pos;
        }

    }

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

