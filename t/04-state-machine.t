#!perl
# -*- cperl -*-

use Test::More tests => 4;
use Test::Exception;
use lib "lib";

use strict;
use warnings;
use Log::Log4perl qw(:easy);
use FindBin qw($Bin);
use File::Temp qw(tempdir);

BEGIN { 
    use_ok('RUM::StateMachine');
}                                               

my $m = RUM::StateMachine->new(
    state_flags => [qw(letters numbers combined sorted)],
    instructions => [qw(cut_first_col
                        cut_second_col
                        cat_cols
                        sort)],
    start_flags => [],
    goal_flags  => [qw(sorted)],
    transitions => [
        [[],                     ["letters"],  "cut_first_col"],
        [[],                     ["numbers"],  "cut_second_col"],
        [["letters", "numbers"], ["combined"], "cat_cols"],
        [["combined"],           ["sorted"],   "sort"]]
);

is_deeply([$m->flags], [qw(letters numbers combined sorted)]);

is($m->{start_state}, 0, "Start state");
is($m->flags_to_state([]), 0, "Flags to state with no flags");
is($m->flags_to_state(["letters"]), 1, "Flags to state with letters");
is($m->flags_to_state("letters"), 1, "Flags to state with letters");
is($m->flags_to_state(["numbers"]), 2, "Flags to state with numbers");
is($m->flags_to_state(["letters", "numbers"]), 3, 
   "Flags to state with letters and numbers");
is($m->flags_to_state(["letters", "numbers", "combined"]), 7, 
   "Flags to state with letters, numbers, and combined");
is($m->flags_to_state(["letters", "numbers", "combined", "sorted"]), 15,
   "Flags to state with all states");

is_deeply($m->state_to_flags(0),
          [],
          "state_to_flags(0)");
is_deeply($m->state_to_flags(7),
          ["letters", "numbers", "combined"],
          "state_to_flags(7)");
    
my $start   = $m->flags_to_state();
my $letters = $m->flags_to_state("letters");
my $numbers = $m->flags_to_state("numbers");
my $combined = $m->flags_to_state("combined");
my $sorted   = $m->flags_to_state("sorted");

is($m->transition($start, "cut_first_col"), $letters,
   "start, cut_first_col -> letters");
is($m->transition($start, "cut_first_col"), $letters,
   "start, cut_first_col -> letters");

my %adj = $m->adjacent($start);
diag "Adj is %adj\n";
is_deeply({$m->adjacent($start)},
          {cut_first_col => $letters,
           cut_second_col => $numbers},
          "States adjacent to start");

is_deeply({$m->adjacent($letters)},
          {
              cut_second_col => $letters | $numbers},
          "States adjacent to $letters");

is_deeply({$m->adjacent($numbers)},
          {
              cut_first_col => $letters | $numbers},
          "States adjacent to $numbers");

is_deeply({$m->adjacent($letters | $numbers)},
          {
              cat_cols => $letters | $numbers | $combined},
          "States reachable from letters | numbers");

is_deeply({$m->adjacent($letters | $numbers | $combined)},
          {
              sort => $letters | $numbers | $combined | $sorted},
          "States reachable from letters | numbers | combined");


my @plan = qw(cut_first_col cut_second_col cat_cols sort);

is_deeply($m->generate(), \@plan, "Generate plan");


