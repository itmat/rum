package RUM::Script::RumToCov;

use strict;
use warnings;
use autodie;

use RUM::UsageErrors;
use Getopt::Long;
use File::Temp;
use RUM::Heap;
use Data::Dumper;
use base 'RUM::Script::Base';

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    $self->{heap} = RUM::Heap->new(\&compare_position);
    return $self;
}

sub compare_position {
    my ($x, $y) = @_;
    return $x->[0] <=> $y->[0];
}

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

        my @a_spans;
        my @b_spans;
        my @spans;
        my $chr = '';

        # Read a line from the input and parse out the chromosome and
        # spans.
        if (defined(my $line = <$in_fh>)) {
            chomp($line);
            (my $readid, $chr, my $spans, my $strand) = split /\t/, $line;    
            
            # Spans look like "start-end[, start-end]...
            @a_spans = map { [split /-/] } split /, /, $spans;

            my $off = tell($in_fh);

            if ($readid =~ /seq.(\d+)a/) {
                my $a_seqnum = $1;
            
                if (defined (my $b_line = <$in_fh>)) {

                    (my $b_readid, my $b_chr, my $b_spans, my $strand) = split /\t/, $b_line;    
                    
                    if ($b_readid =~ /seq.${a_seqnum}b/) {

                        # Spans look like "start-end[, start-end]...
                        @b_spans = map { [split /-/] } split /, /, $b_spans;
                    }
                    else {
                        seek $in_fh, $off, 0;
                    }
                }
                
            }
            
            # Create spans as a list of records of the format [ start,
            # end, coverage ], representing a span where elements from
            # start to end - 1 have the specified coverage. Since we
            # are just processing one read, the coverage for each span
            # is initially 1.
            @spans = map { [ $_->[0] - 1, $_->[1], 1 ] } (@a_spans, @b_spans);
            my @events = map { $_->[0], $_->[1] } @spans;
            @events = sort { $a <=> $b } @events;

            my $printer = sub {
                my ($start, $end, $cov) = @_;
                if ($cov) {
                    print $out_fh join("\t", $last_chr, $start, $end, $cov), "\n";
                    $footprint += $end - $start;
                }
            };
            $self->purge_spans($printer, $events[0]);
        }



        # If we just finished a chromosome, print out the coverage
        if (($last_chr ne '') && ($chr ne $last_chr)) {

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

            if ($chr) {
                $self->logger->debug("Calculating coverage for $chr\n");
            }
            $self->{last_pos} = undef;

        }
        $last_chr = $chr;


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

    # Each span is an array of [ start pos, end pos, coverage ].
    # Translate the spans into an array of events, where each event
    # has a position and a coverage delta. For example the span [ 5,
    # 8, 2 ] translates to [ [5, 2], [8, -2] ], meaning that at
    # position 5 we increase coverage by 2 and at position 8 we
    # decrease coverage by 2.

    for my $span (@{ $spans }) {
        my ($start, $end, $cov_up) = @{ $span };
        my $start_event = [ $start, $cov_up ];
        my $end_event   = [ $end, 0 - $cov_up ];
        $self->{heap}->pushon($start_event);
        $self->{heap}->pushon($end_event);
    }
}

sub next_event {
    my ($self, $max) = @_;
    my $heap = $self->{heap};
    my $event = $heap->peek;

    return if ! defined $event;
    my ($result_pos, $result_cov) = @{ $event };
    if (defined($max) && $result_pos >= $max) {
        return;
    }
    
    $heap->poplowest;
    while (1) {
        my $event = $heap->peek;
        last if ! defined $event;
        last if $event->[0] != $result_pos;
        $result_cov += $event->[1];
        $heap->poplowest;
    }
    return [ $result_pos, $result_cov ];
}

sub purge_spans {
    my ($self, $callback, $max) = @_;

  EVENT: while (defined (my $rec = $self->next_event($max))) {
        my ($pos, $cov_change) = @{ $rec };

        if (defined ($self->{last_pos}) && $pos < $self->{last_pos}) {
            die "Position $pos is less than last position $self->{last_pos}";
        }
        if ( ! $cov_change ) {
            next;
        }

        if (defined ($self->{last_pos})) {
            $callback->($self->{last_pos}, $pos, $self->{cov});
        }
        $self->{cov} += $cov_change;
        $self->{last_pos} = $pos;
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

