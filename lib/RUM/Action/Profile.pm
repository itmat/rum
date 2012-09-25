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
use File::Path qw(rmtree);
use Getopt::Long;
use Text::Wrap qw(wrap fill);
use base 'RUM::Action';
use POSIX qw(mktime);
use Carp;
use List::Util qw(max sum min);
use Cwd qw(realpath);

my $CSS = <<'EOF';
body {
  font-family: "baskerville", "gill sans", "serif";
}
EOF



sub load_events {
    my ($dir, $job_name) = @_;
    my @events;
    find sub {

        if (/rum(_\d+)?\.log/ ||
            /rum_postproc\.log/) {
            my $events = parse_log_file($File::Find::name, $job_name);
            push @events, @{ $events };
        }
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

        if ($step ne $old_step) {
            print "'$old_step' => '$step'\n";
        }
        $result{$step} ||= {};
        for my $job (keys %{ $times->{$old_step} } ) {
            if ($step ne $old_step) {
                print "  $job\n";
            }
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

    return \%result;

}

sub rename_names {
    my ($name_mapping, @names) = @_;
    return map { exists $name_mapping->{$_} ? $name_mapping->{$_} : $_ } @names;
}


sub speedup {
    my ($baseline, $x) = @_;
    if ($x) {
        return $x - $baseline;
    }
    return;
}

sub median {
    my @items = @_;
    @items = sort { $a <=> $b } @items;

    if (! @items ) {
        return undef;
    }
    elsif (@items % 2) {
        return $items[@items / 2];
    }
    else {
        my $low = $items[@items / 2];
        my $high = $items[@items / 2 + 1];
        return ($high - $low) / 2;
    }
}


sub job_total {
    my ($times, $job_name, $f1, $f2) = @_;

    croak "I need f2" unless $f2;

    my @steps = keys %{ $times };
    my @times = map { $_->{$job_name} } values %{ $times };

    my @reduced = map { $f1->(@{ $_ }) } @times;
    @reduced = grep { defined } @reduced;
    return $f2->(@reduced);
}

my @metrics = (
    { name => "Chunks",
      fn   => sub { scalar(@_) },
      do_color => 0,
      desc => 'The number of chunks that the given step was broken into',
      do_percent => 0,
      
  },
    { name => "Total", 
      fn   => \&sum,
      do_color => 1,
      do_percent => 1,
      desc => 'The total time (in seconds) that all chunks spent processing this step.',
 },
    { name => "Per Chunk Avg.", 
      fn   => sub { @_ ? sum(@_) / @_  : undef },
      fmt => '%.2f',
      do_color => 1,
      do_percent => 1,
      desc => 'The average amount of time spent on this step per chunk.'
  },

    { name => "Median Chunk", 
      fn   => \&median,
      fmt => '%.2f',
      do_color => 1,
      do_percent => 1,
      desc => 'The average amount of time spent on this step per chunk.'
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

    rmtree('rum_profile');
    mkdir 'rum_profile';
    open my $html, '>', "rum_profile/index.html";

    open my $css, '>', "rum_profile/profile.css";
    print $css $CSS;

    my @job_name_headers = map {
        my $colspan = 2 * grep { $_->{do_percent} } @metrics;
        "<th colspan=\"$colspan\">$job_names[$_]</th>";
    } (0 .. $#job_names);

    print $html <<"EOF";
<html>
  <head>
    <link rel="stylesheet" type="text/css" href="profile.css"></link>
  </head>
  <body>
    <table>
      <thead>

        <tr>
          <td></td>
          @job_name_headers
        </tr>
        <tr>
          <th>Step</th>
EOF

    my %totals;

    my %slowest_step_time;
    my %fastest_step_time;

    for my $name (@job_names) {
        for my $metric (@metrics) {
            $totals{$name}{$metric->{name}} = job_total($times, $name, $metric->{fn}, \&sum);
            $fastest_step_time{$name}{$metric->{name}} = job_total($times, $name, $metric->{fn}, \&min);
            $slowest_step_time{$name}{$metric->{name}} = job_total($times, $name, $metric->{fn}, \&max);
        }
    }

#    die "Totals are " . Dumper(\%totals);
    for my $i (0 .. $#job_names) {

        for my $metric (@metrics) {
            if (1 || ($i == 0)) {
                print $html "<th>$metric->{name}</th>";
                if ($metric->{do_percent}) {
                    print $html "<th></th>";
                }
            }
            else {
                print $html "<th>$metric->{name}</th><th>(speedup)</th>";
            }
        }
    }
    print $html <<"EOF";

        </tr>
      </thead>
      <tbody>
EOF

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

                    my $slowest = $slowest_step_time{$job}{$metric->{name}};
                    my $fastest = $fastest_step_time{$job}{$metric->{name}};
                    my $spread = $slowest - $fastest;
                    my $ptotal = $spread ? 255 - int (255 * ($val - $fastest) / $spread) : 0;
                    my $color = $metric->{do_color} ? sprintf '#ff%02x%02x', $ptotal, $ptotal : 'white';
                    my $total = $totals{$job}{$metric->{name}};
                    my $percent = $total ? $val / $total : 0;
                    printf $html "<td bgcolor='%s'>$fmt</td>", $color, $val;
                    if ($metric->{do_percent}) {
                        printf $html "<td>%.2f%%</td>", $percent * 100;
                    }
                }
                else {
                    printf $html "<td></td><td></td>";
                }
                if (0 && exists $baseline{$metric->{name}}) {
                    my $speedup = speedup($baseline{$metric->{name}}, $val);
                    if (defined $speedup) {
                        my $color = (
                            $speedup > 1 ? 'green' :
                            $speedup < 1 ? 'red'   : 'white');
                        printf $html "<td>%.2f</td>", $speedup;
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

print $html <<"EOF";
      </tbody>
      <tfoot>
        <tr>
          <th>Whole job</th>
EOF

    for my $i (0 .. $#job_names) {
        for my $metric (@metrics) {
            my $fmt = $metric->{fmt} || '%s';
            printf $html "<td>$fmt</td>", $totals{$job_names[$i]}{$metric->{name}};
                    if ($metric->{do_percent}) {
                        printf $html "<td>%.2f%%</td>", 0.0;
                    }
        }
    }

print $html <<"EOF";
        </tr>
      </tbody>
    </table>
    
    <h2>How to read this profile</h2>

    <p>

Each step of the pipeline is listed, in the order in which the steps
appear in the log files. For each step, we show the number of chunks
that ran it, the time of the chunk that took the longest, the total
time across all chunks, and the average time per chunk. The cells are
color coded according to the proportion of time spent in that step
compared to the steps that took the most and least amount of time. The
redness of the step indicates how long it took, compared to the other
steps: the step that took the longest will be red, the step that took
the least amount of time will be white.

    </p>
EOF


    print $html "<h2>Definitions</h2>\n";

    print $html "<dl>\n";
    for my $metric (@metrics) {
        print $html "<dt>$metric->{name}</dt><dd>$metric->{desc}</dd>\n";
    }
    print $html "</dl>\n";

    print $html '</body></html>';
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

