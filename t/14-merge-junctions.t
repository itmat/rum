#!perl
# -*- cperl -*-

use Test::More tests => 13;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use strict;
use warnings;

BEGIN { 
  use_ok('RUM::Script::MergeJunctions');
}

my @header = qw(intron  strand  score   known   standard_splice_signal  
                 signal_not_canonical    ambiguous      
                 long_overlap_unique_reads
                 short_overlap_unique_reads
                 long_overlap_nu_reads
                 short_overlap_nu_reads);

my $input1 = [
    ["chr1:11-15", ".",  1, 1,  2,  3,  5,  2,  3,  5,  7],
    ["chr1:21-15", ".", 11, 7, 11, 13, 17, 13, 17, 23, 29]];

my $input2 = [
    ["chr1:11-15", ".", 31, 1, 2, 3, 5, 37, 41, 43, 47],
    ["chr1:31-35", ".", 11, 5, 3, 2, 1, 13, 17, 23, 29]];

my $expected = [
    ["chr1:11-15", ".", 32, 1,  2,  3,  5, 39, 44, 48, 54],
    ["chr1:21-15", ".", 11, 7, 11, 13, 17, 13, 17, 23, 29],
    ["chr1:31-35", ".", 11, 5,  3,  2,  1, 13, 17, 23, 29]];

sub format_input {
    my $table = shift;
    my $text = join("\t", @header) . "\n";
    for my $row (@$table) {
        $text .= join("\t", @$row) . "\n";
    }
    return $text;
}

sub make_input {
    my $text = format_input(shift);
    open my $in, "<", \$text;
    return $in;
}

{
    my $script = RUM::Script::MergeJunctions->new();
    $script->read_file(make_input($input1));
    $script->read_file(make_input($input2));
    ok($script->{data}->{"chr1"}{11}{15}, "Read row 1");
    is($script->{data}->{"chr1"}{11}{15}->{score}, 32, "Adds score");

    is($script->{data}->{"chr1"}{11}{15}->{long_overlap_unique_reads}, 39, "Adds long_overlap_unique_reads");
    is($script->{data}->{"chr1"}{11}{15}->{short_overlap_unique_reads}, 44, "Adds short_overlap_unique_reads ");
    is($script->{data}->{"chr1"}{11}{15}->{long_overlap_nu_reads}, 48, "Adds long_overlap_nu_reads");
    is($script->{data}->{"chr1"}{11}{15}->{short_overlap_nu_reads}, 54, "Adds short_overlap_nu_reads");
    is($script->{data}->{"chr1"}{11}{15}->{strand}, ".", "Reads strand");
    is($script->{data}->{"chr1"}{11}{15}->{known}, 1, "Known");
    is($script->{data}->{"chr1"}{11}{15}->{standard_splice_signal}, 2, "Standard splice signal");
    is($script->{data}->{"chr1"}{11}{15}->{signal_not_canonical}, 3, "Signal not canonical");
    is($script->{data}->{"chr1"}{11}{15}->{ambiguous}, 5, "Ambiguous");

    open my $out, ">", \(my $got);
    $script->print_output($out);
    close($out);
    is($got, format_input($expected), "Prints output correctly");
}
