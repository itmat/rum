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

sub load_events {
    my ($dir) = @_;
    my @events;
    find sub {
        return if ! /rum(_\d\d\d)?\.log/;
        my $events = parse_log_file($File::Find::name);
        push @events, @{ $events };
    }, "$dir/log";
    return \@events;
}

sub merge_names {
    my (@name_lists) = @_;

    my @result;
    my %seen;

    for my $names (@name_lists) {
        for my $name (@{ $names }) {
            push @result, $name unless $seen{$name}++;
        }
    }
    return @result;
}

sub rename_steps {
    my ($times, $step_mapping) = @_;

    my %result;
    

    for my $old_step (keys %{ $times }) {

        my @times = @{ $times->{$old_step} };

        if (exists $step_mapping->{$old_step} ) {
            my $new_step = $step_mapping->{$old_step};
            print "'$old_step' => '$new_step'\n";
            print "Times was @times\n";
            if (my $old_times = $result{$new_step}) {
                @times = map { $old_times->[$_] + $times[$_] } (0 .. $#times );
            }
            print "Is now @times\n";
            $result{$new_step} = \@times;
        }
        else {
            $result{$old_step} = \@times;
        }

    }
    return \%result;

}

sub times_for_step {
    my ($times_for_step, $step) = @_;
    if (my $times = $times_for_step->{$step}) {
        return @{ $times };
    }
    return;
}

sub max_time_for_step {
    my ($times_for_step, $step) = @_;
    return max times_for_step($times_for_step, $step);
}

sub total_time_for_step {
    my ($times_for_step, $step) = @_;
    return sum times_for_step($times_for_step, $step);
}

sub avg_time_for_step {
    my ($times_for_step, $step) = @_;
    my @times = times_for_step($times_for_step, $step);
    if (@times) {
        return sum(@times) / @times;
    }
    return;
}

sub rename_names {
    my ($name_mapping, @names) = @_;
    return map { exists $name_mapping->{$_} ? $name_mapping->{$_} : $_ } @names;
}

sub run {
    my ($class) = @_;

    my @dirs = @ARGV;

    my $name_mapping = {
        'Run bowtie on genome'       => 'Run Bowtie on genome',
        'Parse genome Bowtie output' => 'Run Bowtie on genome',
        'Run bowtie on transcriptome'       => 'Run Bowtie on transcriptome',
        'Parse transcriptome Bowtie output' => 'Run Bowtie on transcriptome',
        'Run blat on unmapped reads'        => 'Run BLAT',
        'Parse blat output'                 => 'Run BLAT',
        'Run mdust on unmapped reads'                 => 'Run BLAT',

    };

    my @event_lists  = map { load_events($_)   }  @dirs;
    my @timing_lists = map { build_timings($_) } @event_lists;
    my @name_lists   = map { ordered_steps($_) } @timing_lists;
    my @time_lists   = map { times_by_step($_) } @timing_lists;

    print "Before names are " . Dumper(\@name_lists);
    @name_lists = map { [ rename_names($name_mapping, @$_) ] } @name_lists;
    print "After names are " . Dumper(\@name_lists);
    my @names = merge_names(@name_lists);

    my (@max, @sum, @avg);


            
    @time_lists = map { rename_steps($_, $name_mapping) } @time_lists;

    
    open my $html, '>', "rum_profile.html";

    print $html "<html><head></head><body><table>";

    print $html "<tr>\n";
    print $html '<th>Step</th>';
    
    for my $times (@time_lists) {
        print $html '<th>Max</th><th>Sum</th><th>Avg</th>';
    }
    print $html '</tr>';

    for my $i (0 .. $#names) {
        print $html '<tr>';

        my $step = $names[$i];
        print $html "<td>$step</td>";

        for my $times (@time_lists) {
            my $print_td = sub {
                my $val = shift;
                my $fmt = shift || '%s';
                if (defined $val) {
                    printf $html "<td";
                    printf $html ">$fmt</td>", $val;
                }
                else {
                    printf $html "<td></td>";
                }
            };

            $print_td->(max_time_for_step($times, $step));
            $print_td->(total_time_for_step($times, $step));
            $print_td->(avg_time_for_step($times, $step), '%.2f');
        }
        print $html '</tr>';
    }

    print $html '</table></body></html>';
}

sub parse_log_file {
    my ($filename) = @_;
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
    my ($events) = @_;
    
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
    my ($timings) = @_;

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
    my ($timings, $f) = @_;

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

