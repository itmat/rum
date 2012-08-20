package RUM::Action::Profile;

=head1 NAME

RUM::Action::Profile - Action for printing performance stats

=head1 METHODS

=over 4

=cut

use strict;
use warnings;
use autodie;
use Data::Dumper;
use File::Find;
use Getopt::Long;
use Text::Wrap qw(wrap fill);
use base 'RUM::Action';
use POSIX qw(mktime);
use Carp;
use List::Util qw(max sum);

=item run

Run the action. Parses command line args, parses all the log files for
the specified job, builds timing counts, and prints stats.

=cut

sub run {
    my ($class) = @_;
    my $self = $class->new(name => 'profile');

    GetOptions(
        "output|o=s" => \(my $dir)
    );

    my $config = RUM::Config->load($dir);

    my @all_events;
    
    find sub {
        return if ! /rum(_\d\d\d)?\.log/;
        print "$_\n";
        my $events = $self->parse_log_file($File::Find::name);
        push @all_events, @{ $events };
    }, "$dir/log";

    my $timings = $self->build_timings(\@all_events);
    warn "Timings is " . Dumper($timings);
    my $names = $self->ordered_steps($timings);
    my $times = $self->times_by_step($timings);

    my @names = @{ $names };
    my (@max, @sum, @avg);

    for my $name (@names) {
        my @times = @{ $times->{$name} };
        push @max, max(@times);
        push @sum, sum(@times);
        push @avg, sum(@times) / @times;
    }

    push @names, 'Whole job';
    push @max,   sum(@max);
    push @sum,   sum(@sum);
    push @avg,   sum(@avg);

    for my $i (0 .. $#names) {
        printf "%50s %6d %6d %6d\n", $names[$i], $max[$i], $sum[$i], $avg[$i];
    }
}

=item parse_log_file($in)

Parse the data from the given filehandle and return an array ref of
array refs, where each record is [$time, $type, $module]. $time is the
time that an event occurred, $type is either START or FINISHED, and
module is the RUM::Script::* module that either started or finished at
the given time.

=cut

sub parse_log_file {
    my ($self, $filename) = @_;

    open my $in, '<', $filename;

    my $time_re = qr((\d{4})/(\d{2})/(\d{2}) (\d{2}):(\d{2}):(\d{2}));

    my @events;

    while (defined(my $line = <$in>)) {
        my @parts = $line =~ /$time_re.*RUM\.Workflow.*(START|FINISH): (.*)/g or next;
        my ($year, $month, $day,  $hour, $minute, $second, $type, $step) = @parts;
        my $time = mktime($second, $minute, $hour, $day, $month - 1, $year + 1900);
        push @events, {
            time => $time,
            type => $type,
            step => $step
        };
    }
    return \@events;
}

=item build_timings($events)

Takes an array of events as returned by parse_log_file and returns a
map from module name to total time.

=cut

sub build_timings {
    my ($self, $events) = @_;
    
    my @stack;

    my @timings;

    for my $event (@{ $events }) {
        my $time = $event->{time};
        my $type = $event->{type};
        my $step = $event->{step};
        warn "Type is $type\n";
        if ($type eq 'START') {
            push @stack, $event;
        }
        elsif ($type eq 'FINISH') {
            my $prev = pop @stack or croak "No start event for $@event";
            my $prev_time = $prev->{time};
            my $prev_step = $prev->{step};

            if ($prev_step ne $step) {
                croak "Can't build timings from log file";
            }
            
            push @timings, {
                step  => $step,
                start => $prev_time,
                stop  => $time
            };
        }
    }

    @timings = sort { $a->{start} <=> $b->{start} } @timings;
    return \@timings;
}

sub ordered_steps {
    my ($self, $timings) = @_;

    my @steps;
    my %seen;

    for my $timing (@{ $timings }) {
        my $step = $timing->{step};
        if (!$seen{$step}++) {
            push @steps, $step;
        }
    }
    return \@steps;
}

sub times_by_step {
    my ($self, $timings, $f) = @_;

    my %times;

    for my $timing (@{ $timings }) {
        my $step = $timing->{step};
        my $time = $timing->{stop} - $timing->{start};
        push @{ $times{$step} ||= [] }, $time;
    }
    return \%times;
}

1;

=back

