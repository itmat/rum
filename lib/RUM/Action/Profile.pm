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
use Cwd qw(realpath);


sub run {
    my ($class) = @_;
    my $self = $class->new(name => 'profile');

    GetOptions(
        "output|o=s" => \(my $dir)
    );

    my @all_events;
    
    find sub {
        return if ! /rum(_\d\d\d)?\.log/;
        my $events = $self->parse_log_file($File::Find::name);
        push @all_events, @{ $events };
    }, "$dir/log";

    my $timings = $self->build_timings(\@all_events);
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

    printf "%50s %10s %10s %10s\n", 'Step', 'Max', 'Sum', 'Agv';
    for my $i (0 .. $#names) {
        if ($i == $#names) {
            my $len = 50 + 1 + 10 + 1 + 10 + 1 + 10;
            print '-' x $len, "\n";
        }
        printf "%50s %10d %10d %10d\n", $names[$i], $max[$i], $sum[$i], $avg[$i];
    }


}

sub parse_log_file {
    my ($self, $filename) = @_;
    print "Parsing $filename\n";
    open my $in, '<', $filename;

    my $time_re = qr((\d{4})/(\d{2})/(\d{2}) (\d{2}):(\d{2}):(\d{2}));

    my @events;

    while (defined(my $line = <$in>)) {
        my @parts = $line =~ /$time_re.*RUM\.Workflow.*(START|FINISH)\s+(.*)/g or next;
        my ($year, $month, $day,  $hour, $minute, $second, $type, $step) = @parts;
        my $time = mktime($second, $minute, $hour, $day, $month - 1, $year + 1900);
        push @events, {
            time => $time,
            type => $type,
            step => $step
        };
    }
    printf "Found %d events\n", scalar @events;
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

