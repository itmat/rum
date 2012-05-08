#!/usr/bin/env perl

###############################################################################
##
## Modeling task dependencies
## 

package RUM::Rules;

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    return bless {
        rules => []
    }, $class;
}

sub add {
    my ($self, $targets, $prereqs, $commands, $comments) = @_;
    push @{ $self->{rules} }, {
        targets => $targets,
        prereqs => $prereqs,
        commands => $commands,
        comments => $comments
    };
}

sub makefile {
    my ($self) = @_;
    my $result  = "";
    my @clean;
    for my $rule (@{ $self->{rules} }) {
        my @targets = @{ $rule->{targets} };
        my @prereqs = @{ $rule->{prereqs} };
        my @commands = @{ $rule->{commands} };
        my $comments = $rule->{comments};

        push @clean, @targets;

        $result .= "# $comments\n" if $comments;
        $result .= "@targets : @prereqs\n";
        for my $command (@commands) {
            $result .= "\t$command\n";
        }
        $result .= "\n";
    }
    
    $result .= "clean :\n\trm -f @clean\n";

    return $result;
}

###############################################################################
##
## Main command line tool
## 

package RUM::Script::Sort;

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use Getopt::Long;
use Carp;
use File::Temp;
use RUM::FileIterator qw(file_iterator sort_by_location);
use RUM::Sort qw(by_location);
use RUM::Logger;

our $log = RUM::Logger->get_logger(__PACKAGE__);

sub main {

    $log->info("Running $0 @ARGV");

    GetOptions("--max-chunk-size|n=s", => \(my $max_chunk_size),
               "--plan"     => \(my $do_plan = 0),
               "--split"    => \(my $do_split = 0),
               "--merge"    => \(my $do_merge = 0),
               "--start=s"  => \(my $start),
               "--size=s"   => \(my $size),
               "--output|o=s" => \(my $output),
               "--makefile=s" => \(my $makefile));

    if ($do_plan + $do_split + $do_merge != 1) {
        die("Please specify exactly one of --plan, --split, or --merge\n");
    }

    $output or die "Please specify --output\n";

    if ($do_plan) {

        my ($input) = @ARGV or die("Please specify an input file\n");

        $makefile or die "If you say --plan, please specify a location for ".
            "the Makefile with --makefile\n";
        $max_chunk_size or die "Please specify --max-chunk-size\n";

        $log->info("Building plan");
        my $planner = RUM::Script::Sort->new(
            input => $input,
            output => $output,
            max_chunk_size => $max_chunk_size);
        $planner->add_splits(output => $output);

        $log->info("Building makefile");
        open my $out, ">", $makefile 
            or $log->logdie("Can't open $makefile for writing: $!");
        print $out $planner->{rules}->makefile();
        close $out;
    }

    elsif ($do_split) {
        my ($input) = @ARGV or die("Please specify an input file\n");

        $log->debug(
            "Reading up to $size bytes from $input starting at $start");
        open my $in, "<", $input 
            or $log->logdie("Can't open $input for reading: $!");
        seek $in, $start, 0;
        my @lines;

        if ($start > 0) {
            <$in>;
        }
        my $end = tell($in) + $size;
        open my $out, ">", $output 
            or $log->logdie("Can't open $output for writing: $!");
        $log->debug("Sorting until $end") if $log->is_debug;
        sort_by_location($in, $out, end => $end);
        $log->debug("File position is now ".tell($in)) if $log->is_debug;

    }
    
    elsif ($do_merge) {
        my @inputs = @ARGV;
        @inputs == 2 or die "Please tell me two files to merge\n";

        open my $lf, "<", $inputs[0]
            or $log->logdie("Can't open $inputs[0] for reading: $!");
        open my $rf, "<", $inputs[1]
            or $log->logdie("Can't open $inputs[1] for reading: $!");
        open my $out, ">", $output
            or $log->logdie("Can't open $output for writing: $!");

        $log->info("Merging $inputs[0] and $inputs[1]");

        my $l = file_iterator($lf);
        my $r = file_iterator($rf);

        my $count = 0;

        my $print_from_iter = sub {
            my ($iter) = @_;
            $count++;
            print $out $iter->("pop")->{entry}, "\n";
        };

        while ($l->("peek") && $r->("peek")) {
            my $min;
            if (by_location($l->("peek"), $r->("peek")) < 0) {
                $print_from_iter->($l);
            }
            else {
                $print_from_iter->($r);
            }
        }
        while ($l->("peek")) {
            $print_from_iter->($l);
        }
        while ($r->("peek")) {
            $print_from_iter->($r);
        }
        $log->debug("Printed $count lines") if $log->is_debug;
    }
}

sub new {
    my ($class, %options) = @_;
    my $self = {};
    $self->{max_chunk_size} = delete $options{max_chunk_size};
    $self->{input}          = delete $options{input};
    $self->{output}         = delete $options{output};
    $self->{rules}          = RUM::Rules->new();
    $self->{rules}->add(["all"], [$self->{output}], []);
    return bless $self, $class;
}

sub add_splits {
    my ($self, %options) = @_;

    my $input  = $self->{input} or croak "Need input";
    my $rules  = $self->{rules};

    my $output = $options{output};
    my $start  = $options{start} || 0;
    my $size   = $options{size};

    unless ($size) {
        $size = -s $input or $log->logdie("Can't get size of $input: $!");
    }

    $log->debug("Adding splits for $input; $size from $start")
        if $log->is_debug;

    # The program that actually does the sorting or merging will write
    # to this temp file and then move the temp file to the proper
    # location of the output file. This ensures that if we crash for
    # some reason, the output is either fully written or not written
    # at all.
    my $tmp = File::Temp->new(
        TEMPLATE => "sort.XXXXXX", DIR => ".")->filename;

    # If the size that I'm supposed to sort is smaller than the max
    # chunk size, just add a rule that sorts my section of the input
    # file directly.
    if ($size <= $self->{max_chunk_size}) {
        $log->debug("At a leaf node, size is $size") if $log->is_debug;
        $rules->add([$output], [$input],
                    ["$0 --split --start $start --size $size --output $tmp $input",
                     "mv $tmp $output"],
                    "Sort $size bytes starting at $start");
    }

    # Otherwise I need to create two rules that each sort a chunk of
    # the file and a third rule that merges the sorted chunks back
    # together.
    else {
        
        # One rule will sort from $start to $start + $size / 2 and
        # store the results here.
        my $l_start = $start;
        my $l_size  = int($size / 2);
        my $left  = File::Temp->new(
            TEMPLATE => "sort.XXXXXX", 
            DIR => ".")->filename;

        # The other rule will sort from $start + $size / 2 to $start +
        # $size and store the results here.
        my $r_start = $start + $l_size;
        my $r_size  = $size - $l_size;
        my $right = File::Temp->new(
            TEMPLATE => "sort.XXXXXX", 
            DIR => ".")->filename;

        $self->add_splits(output => $left,
                          start  => $l_start,
                          size   => $l_size);

        $self->add_splits(output => $right,
                          start  => $r_start,
                          size   => $r_size);

        # Then we need a rule to merge the two sorted chunks together.
        $rules->add([$output], [$left, $right],
                    ["$0 --merge $left $right --output $tmp",
                     "mv $tmp $output"],
                    "Merge $l_size bytes from $l_start and $r_size bytes from $r_start");
    }
}

__PACKAGE__->main();
