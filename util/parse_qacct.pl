#!/usr/bin/env perl

use strict;
use warnings;

use List::Util qw(reduce max);

my @jobs;

our @FIELDS = qw(
qname
hostname
jobname
jobnumber
taskid
qsub_time
start_time
end_time
tot_time
ru_wallclock
ru_utime
ru_stime
ru_maxrss
ru_minflt
ru_majflt
ru_nvcsw
ru_nivcsw
cpu
mem
io
maxvmem);

while (defined(local $_ = <ARGV>)) {
    if (/^=+$/) {
        push @jobs, {};
    }
    else {
        chomp;
        my ($k, $v) = split /\s+/, $_, 2;
        $v =~ s/^\s*//;
        $v =~ s/\s*$//;
        $jobs[$#jobs]->{$k} = $v;
    }
}

my @formats;

local $_;


sub format_time {
    my ($time) = @_;
    
    my $hours = int($time / (60 * 60));
    $time -= ($hours * 60 * 60);
    my $minutes = int($time / 60);
    $time -= $minutes * 60;

    sprintf "%02d:%02d:%02d", $hours, $minutes, $time;
}

for my $i (0 .. $#jobs) {
    for my $field (qw(qsub_time start_time end_time)) {
        $jobs[$i]{$field} = substr $jobs[$i]{$field}, 11, 8;
    }

    $jobs[$i]->{tot_time} = format_time($jobs[$i]->{ru_wallclock});
}

for (@FIELDS) {
    my $width = length;

    for my $job (@jobs) {
        my $len = length($job->{$_});
        $width = $len if $len > $width;
    }

    push @formats, "%${width}s";
}

my $format = "@formats\n";
printf $format, @FIELDS;


my @parent = grep { $_->{jobname} =~ /rum_runner/ } @jobs;
my @preproc = grep { $_->{jobname} =~ /_preproc/ } @jobs;
my @proc = grep { $_->{jobname} =~ /_proc/ } @jobs;
my @postproc = grep { $_->{jobname} =~ /_postproc/ } @jobs;

@proc = sort { $a->{taskid} <=> $b->{taskid} } @proc;

for my $job (@parent, @preproc, @proc, @postproc) {

    my @vals = @$job{@FIELDS};

    printf $format, @vals;
}

my @chunk_times = map $_->{ru_wallclock}, @proc;

my $chunk_time = reduce { $a + $b } @chunk_times;

my @total_times = map $_->{ru_wallclock}, @preproc, @proc, @postproc;
my $total_time = reduce { $a + $b } @total_times;

printf "\nSummary:\n";
printf "--------\n";
printf "Total job time: %s\n", format_time($total_time);
printf " Preprocessing: %s\n", format_time($preproc[0]->{ru_wallclock});
printf "    Avg. chunk: %s\n", format_time($chunk_time / @proc);
printf "    Max. chunk: %s\n", format_time(max @chunk_times);
printf "Postprocessing: %s\n", format_time($postproc[0]->{ru_wallclock});
