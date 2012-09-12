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
    my ($dir, $job_name) = @_;
    my @events;
    find sub {
        return if ! /rum(_\d\d\d)?\.log/;
        my $events = parse_log_file($File::Find::name, $job_name);
        push @events, @{ $events };
    }, "$dir/log";
    return \@events;
}

sub merge_names {
    my (@names) = @_;

    my @result;
    my %seen;

    for my $name (@names) {
        push @result, $name unless $seen{$name}++;
    }
    return @result;
}

sub rename_steps {
    my ($times, $step_mapping) = @_;

    my %result;

    for my $old_step (keys %{ $times }) {

        my $step = exists $step_mapping->{$old_step} ? $step_mapping->{$old_step} : $old_step;
        print "'$old_step' => '$step'\n";
        $result{$step} ||= {};
        for my $job (keys %{ $times->{$old_step} } ) {
            my @these_times = @{ $times->{$old_step}{$job} };
            if (my $acc_times = $result{$step}{$job}) {
                for my $i ( 0 .. $#these_times ) {
                    $acc_times->[$i] += $these_times[$i];
                }
            }
            else {
                $result{$step}{$job} = \@these_times;
            }
        }
    }

    print Dumper(\%result);
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


sub speedup {
    my ($baseline, $x) = @_;
    if ($x) {
        return $baseline / $x;
    }
    return;
}



sub job_total {
    my ($times, $job, $f) = @_;

    my @steps = keys %{ $times };
    my @times = map { $_->{$job} } values %{ $times };

    my @reduced = map { $f->(@{ $_ }) } @times;
    return sum @reduced;
}

my @metrics = (
    { name => "Max",
      fn   => \&max },
    { name => "Total", 
      fn   => \&sum },
    { name => "Avg", 
      fn   => sub { sum(@_) / @_ },
      fmt => '%.2f'
  },
);

sub run {
    my ($class) = @_;

    my @dirs;
    my @job_names;
    
    while (my $spec = shift @ARGV) {
        my ($job, $dir) = split /=/, $spec, 2;
        die unless $job && $dir;
        push @dirs, glob $dir;
        push @job_names, $job;
    }

    my $name_mapping = {
        'Run bowtie on genome'              => 'Run Bowtie on genome',
        'Parse genome Bowtie output'        => 'Run Bowtie on genome',
        'Run bowtie on transcriptome'       => 'Run Bowtie on transcriptome',
        'Parse transcriptome Bowtie output' => 'Run Bowtie on transcriptome',
        'Run blat on unmapped reads'        => 'Run BLAT',
        'Parse blat output'                 => 'Run BLAT',
        'Run mdust on unmapped reads'       => 'Run BLAT',

    };

    my @event_lists;
    for my $i (0 .. $#dirs) {
        push @event_lists, load_events($dirs[$i], $job_names[$i]);
    }

    my @times = map { build_timings($_) } @event_lists;
    @times = map { @$_ } @times;

    my $times = times_by_step(\@times);

    my @names = merge_names(rename_names($name_mapping, ordered_steps(\@times)));


    my (@max, @sum, @avg);
    
    $times = rename_steps($times, $name_mapping);

    open my $html, '>', "rum_profile.html";

    print $html "<html><head></head><body><table>";

    print $html "<tr><td></td>";
    for my $i (0 .. $#job_names) {
        my $colspan = $i ? @metrics * 2 : @metrics;
        print $html "<th colspan=\"$colspan\">$job_names[$i]</th>";
    }
    print $html "<tr>\n";

    print $html "<tr>\n";
    print $html '<th>Step</th>';

    my %totals;

    for my $name (@job_names) {
        for my $metric (@metrics) {
            $totals{$name}{$metric->{name}} = job_total($times, $name, $metric->{fn});
        }
    }

    
    for my $i (0 .. $#job_names) {

        for my $metric (@metrics) {
            if ($i == 0) {
                print $html "<th>$metric->{name}</th>";
            }
            else {
                print $html "<th>$metric->{name}</th><th>(speedup)</th>";
            }
        }
    }
    print $html '</tr>';

    for my $i (0 .. $#names) {
        print $html '<tr>';

        my $step = $names[$i];
        print $html "<td>$step</td>";

        my %baseline;

        for my $j (0 .. $#job_names) {
            my $job = $job_names[$j];
            my @job_step_times = @{ $times->{$step}->{$job} || [] };

            for my $metric (@metrics) {
                my $val = $metric->{fn}->(@job_step_times);
                if (defined $val) {
                    my $fmt = $metric->{fmt} || '%s';
                    my $ptotal = $val / $totals{$job}{$metric->{name}};
                    
                    printf $html "<td>$fmt</td>", $val;

                }
                else {
                    printf $html "<td></td>";
                }
                if (exists $baseline{$metric->{name}}) {
                    my $speedup = speedup($baseline{$metric->{name}}, $val);
                    if (defined $speedup) {
                        my $color = (
                            $speedup > 1 ? 'green' :
                            $speedup < 1 ? 'red'   : 'white');
                        printf $html "<td bgcolor='$color'>%.2fx</td>", $speedup;
                    }
                    else {
                        print $html "<td></td>";
                    }
                }
                else {
                    $baseline{$metric->{name}} = $val;
                }
            }

        }
        print $html '</tr>';
    }

    print $html "<tr><th>Whole job</th>";


    for my $i (0 .. $#job_names) {
        for my $metric (@metrics) {
            print $html "<td>" . $totals{$job_names[$i]}{$metric->{name}} . "</td>";
        }
        if ($i) {
            print $html "<td></td>"
        }
    }
    print $html "</tr>";
    print $html '</table></body></html>';
}

sub parse_log_file {
    my ($filename, $job_name) = @_;
    print "Parsing $filename for job '$job_name'\n";
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
            step => $step,
            job  => $job_name
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
        my $job  = $event->{job};

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
                stop  => $time,
                job   => $job
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
    return @steps;
}

sub times_by_step {
    my ($timings, $f) = @_;

    my %times;

    for my $timing (@{ $timings }) {
        my $step = $timing->{step};
        my $time = $timing->{stop} - $timing->{start};
        my $job = $timing->{job};

        push @{ $times{$step}{$job} ||= [] }, $time;
    }
    return \%times;
}

1;

=back

