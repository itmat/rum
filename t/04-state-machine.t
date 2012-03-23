#!perl
# -*- cperl -*-

use Test::More tests => 24;
use Test::Exception;
use lib "lib";

use strict;
use warnings;

BEGIN { 
    use_ok('RUM::StateMachine');
}                                               

my $m = RUM::StateMachine->new(start => 0);

my $start = $m->start;
my $letters = $m->flag("letters");
my $numbers = $m->flag("numbers");
my $combined = $m->flag("combined");
my $sorted = $m->flag("sorted");

$m->add("Cut the letters column out", $start, $letters, "cut_first_col");
$m->add("Cut the numbers column out", $start, $numbers, "cut_second_col");
$m->add($letters | $numbers, $combined, "cat_cols");
$m->add($combined, $sorted, "sort");

$m->set_goal($sorted);

is_deeply([sort $m->flags], [qw(combined letters numbers sorted)],
      "flags");

is($start, 0, "start");
is($letters, 1, "letters");
is($numbers, 2, "numbers");
is($combined, 4, "combined");
is($sorted,   8, "sorted");
is($m->flag("letters"), 1, "flag again");

is_deeply([sort $m->flags($combined | $letters)],
          ["combined", "letters"],
          "Flags with arg");

is($m->state("letters"), $letters, "state");
is($m->state("letters", "numbers"), $letters | $numbers, "state");
is($m->state("letters", "numbers", "combined"), $letters | $numbers | $combined,
   "state");

is($m->transition($start, "cut_first_col"), $letters,
   "start, cut_first_col -> letters");
is($m->transition($start, "cut_second_col"), $numbers,
   "start, cut_second_col -> numbers");

my ($new_state, $comment) = $m->transition($start, "cut_first_col");
is($new_state, $letters, "Transition in array context");
is($comment, "Cut the letters column out", "Get comment");

my ($same_state, $same_comment) = $m->transition($start, "sort");
is($same_state, $start, "Invalid transition");
is($same_comment, "", "Comment for invalid transition");

my %adj = $m->_adjacent($start);
is_deeply({$m->_adjacent($start)},
          {cut_first_col => $letters,
           cut_second_col => $numbers},
          "States adjacent to start");

is_deeply({$m->_adjacent($letters)},
          {
              cut_second_col => $letters | $numbers},
          "States adjacent to $letters");

is_deeply({$m->_adjacent($numbers)},
          {
              cut_first_col => $letters | $numbers},
          "States adjacent to $numbers");

is_deeply({$m->_adjacent($letters | $numbers)},
          {
              cat_cols => $letters | $numbers | $combined},
          "States reachable from letters | numbers");

is_deeply({$m->_adjacent($letters | $numbers | $combined)},
          {
              sort => $letters | $numbers | $combined | $sorted},
          "States reachable from letters | numbers | combined");

my @plan = qw(cut_first_col cut_second_col cat_cols sort);

is_deeply($m->generate(), \@plan, "Generate plan");



__END__

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








