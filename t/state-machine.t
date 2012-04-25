use strict;
use warnings;

use Test::More tests => 39;
use lib "lib";
use Data::Dumper;


BEGIN { 
    use_ok('RUM::StateMachine');
}                                               

my $m = RUM::StateMachine->new(start => 0);

my $start = $m->start;
my $letters = $m->flag("letters");
my $numbers = $m->flag("numbers");
my $combined = $m->flag("combined");
my $sorted = $m->flag("sorted");

$m->add($start, $letters, "cut_first_col");
$m->add($start, $numbers, "cut_second_col");
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

my $new_state = $m->transition($start, "cut_first_col");
is($new_state, $letters, "Transition in array context");

my $same_state = $m->transition($start, "sort");
is($same_state, $start, "Invalid transition");

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


is_deeply($m->plan(), \@plan, "Generate plan");

my @dfs;

$m->dfs(sub { push @dfs, [@_] });

is_deeply(\@dfs,
          [[0, "cut_first_col", 1],
           [1, "cut_second_col", 3],
           [3, "cat_cols", 7],
           [7, "sort", 15],
           [0, "cut_second_col", 2],
           [2, "cut_first_col", 3]       
       ],
          "DFS");

open my $dot, ">", "workflow.dot";
$m->dotty($dot);
close ($dot);


{

    my @expected = (
        [ 0, 'cut_first_col',  $letters],
        [ 0, 'cut_second_col', $numbers],
        [ $letters, 'cut_second_col', $letters | $numbers],
        [ $letters | $numbers , 'cat_cols', $letters | $numbers | $combined ],
        [ $letters | $numbers | $combined, 'sort', $letters | $numbers | $combined | $sorted ]
    );

    my @expected_plan = qw(cut_letters cut_numbers cat_cols sort);

    my @expected_minimal_states = (
        $sorted | $combined | $numbers | $letters,
        $sorted | $combined | $numbers | $letters,
        $sorted | $combined,
        $sorted
    );

    my @expected_path = (
        0, 
        $letters,
        $letters | $numbers,
        $letters | $numbers | $combined,
        $letters | $numbers | $combined | $sorted
    );

    my @traversal;
    ok $m->bfs(sub { push @traversal, [@_] }), "BFS finds path";
    is_deeply \@traversal, \@expected, "Traversal of BFS";

    my $min_states = $m->minimal_states;
    is_deeply $min_states, \@expected_minimal_states, "Minimal states";

    for my $state (@$min_states) {
        my @flags = $m->flags($state);
        warn "Flags are @flags\n";
    }

}

ok $m->recognize([], $sorted), "Already at goal";
ok $m->recognize(['sort'], $combined), "Just need to sort";
ok $m->recognize(['cat_cols', 'sort'], $letters | $numbers), "Combine and sort";
ok $m->recognize(['cut_second_col', 'cat_cols', 'sort'], $letters), "Cut numbers, combine and sort";
ok $m->recognize(['cut_first_col', 'cat_cols', 'sort'], $numbers), "Cut numbers, combine and sort";
ok $m->recognize(['cut_first_col', 'cut_second_col', 'cat_cols', 'sort'], 0), "Cut both cols, combine and sort";

ok ! $m->recognize([], 0), "Bad plan";
ok ! $m->recognize(['sort'], 0), "Bad plan";

{
    my @plan = qw(cut_first_col cut_second_col cat_cols sort);
    
    is $m->skippable(\@plan, 0), 0, "Can't skip any";
    is $m->skippable(\@plan, $letters), 1, "Skip cutting letters";
    is $m->skippable(\@plan, $letters | $numbers), 2, "Skip cutting letters and numbers";
    is $m->skippable(\@plan, $combined), 3, "Skip cutting and combining";
    is $m->skippable(\@plan, $sorted), 4, "Skip everything";
}

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

