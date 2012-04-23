package RUM::Action::Profile;

=head1 NAME

RUM::Action::Profile - Action for printing performance stats

=head1 METHODS

use strict;
use warnings;

use Getopt::Long;
use Text::Wrap qw(wrap fill);
use Time::Piece;
use base 'RUM::Action';
use POSIX qw(mktime);
use Carp;

=item run

Run the action. Parses command line args, parses all the log files for
the specified job, builds timing counts, and prints stats.

=cut

sub run {

    my $self = __PACKAGE__->new;

    GetOptions(
        "output|o=s" => \(my $dir)
    );

    my $config = RUM::Config->load($dir);
    
    for my $chunk ( 1 .. $config->num_chunks) {
        my $file = RUM::Logging->log_file($chunk);
        print "Chunk is $file\n";
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
    my ($self, $in) = @_;
    local $_;
    my $time_re = qr((\d{4})/(\d{2})/(\d{2}) (\d{2}):(\d{2}):(\d{2}));

    my @events;

    while (defined($_ = <$in>)) {
        my @parts = /$time_re.*ScriptRunner.*(START|FINISHED) ([\w:]+) /g or next;
        my ($year, $month, $day,  $hour, $minute, $second, $type, $module) = @parts;
        my $time = mktime($second, $minute, $hour, $day, $month - 1, $year + 1900);
        push @events, [$time, $type, $module];
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

    my %times;

    for my $event (@{ $events }) {
        my ($time, $type, $module) = @{ $event };
        if ($type eq "START") {
            push @stack, $event;
        }
        elsif ($type eq "FINISHED") {
            my $prev = pop @stack or croak "No start event for $@event";
            my ($prev_time, $prev_type, $prev_module) = @{ $prev };
            if ($prev_module ne $module) {
                croak "Can't build timings from log file";
            }
            $times{$module} ||= 0;
            $times{$module} += ($time - $prev_time);
        }
    }
    return \%times;
}

1;
