use strict;
use warnings;

use Test::More tests => 31;
use lib "lib";
use Data::Dumper;


BEGIN { 
    use_ok('RUM::StateMachine') or BAIL_OUT "Can't even load StateMachine";
}                                               

my $m = RUM::StateMachine->new();

my $start    = $m->start;
my $letters  = $m->state($m->flag("letters"));
my $numbers  = $m->state($m->flag("numbers"));
my $combined = $m->state($m->flag("combined"));
my $sorted   = $m->state($m->flag("sorted"));

my $letters_numbers = $letters->union($numbers);

ok $letters_numbers->contains($letters), "Contains";

ok ! $letters_numbers->contains($sorted), "Doesn't contain";

ok $letters->intersect($numbers)->is_empty, "Empty intersection";

ok $letters->intersect($letters_numbers), "Non-empty intersection";

$m->add($start, $letters, "cut_first_col");
$m->add($start, $numbers, "cut_second_col");
$m->add($letters_numbers, $combined, "cat_cols");
$m->add($combined, $sorted, "sort");

$m->set_goal($sorted);

is_deeply([sort $m->flags], [qw(combined letters numbers sorted)],
      "flags");

is_deeply $m->state("letters"), $letters, "state";
is_deeply $m->state("letters", "numbers"), $letters_numbers, "state";
is_deeply $m->state("letters", "numbers", "combined"), $letters_numbers->union($combined),
   "state";

is_deeply $m->transition($start, "cut_first_col"), $letters,
   "start, cut_first_col -> letters";
is_deeply $m->transition($start, "cut_second_col"), $numbers,
   "start, cut_second_col -> numbers";

my $new_state = $m->transition($start, "cut_first_col");
is_deeply $new_state, $letters, "Transition in array context";

my $same_state = $m->transition($start, "sort");
is_deeply $same_state, $start, "Invalid transition";

my @plan = qw(cut_first_col cut_second_col cat_cols sort);

my @dfs;
$m->dfs(sub { push @dfs, [@_] });

is_deeply(\@dfs,
          [[$start, "cut_first_col", $letters],
           [$letters, "cut_second_col", $letters->union($numbers)],
           [$letters->union($numbers), "cat_cols", $letters->union($numbers, $combined)],
           [$letters->union($numbers, $combined), "sort", $m->closure],
           [$start, "cut_second_col", $numbers],
           [$numbers, "cut_first_col", $letters->union($numbers)]       
       ],
          "DFS");

is_deeply($m->plan(), \@plan, "Generate plan");

#$m->dotty($dot);


{

    my @expected = (
        [ $start, 'cut_first_col',  $letters],
        [ $start, 'cut_second_col', $numbers],
        [ $letters, 'cut_second_col', $letters->union($numbers)],
        [ $letters->union($numbers), 'cat_cols', $letters->union($numbers, $combined) ],
        [ $letters->union($numbers, $combined), 'sort', $letters->union($numbers, $combined, $sorted) ]
    );

    my @expected_plan = qw(cut_letters cut_numbers cat_cols sort);

    my @expected_minimal_states = (
        $sorted->union($combined, $numbers, $letters),
        $sorted->union($combined, $numbers, $letters),
        $sorted->union($combined),
        $sorted
    );

    my @traversal;
    ok $m->bfs(sub { push @traversal, [@_] }), "BFS finds path";
    is_deeply \@traversal, \@expected, "Traversal of BFS";

    my $min_states = $m->minimal_states;
    is_deeply $min_states, \@expected_minimal_states, "Minimal states";
}

ok $m->recognize([], $sorted), "Already at goal";
ok $m->recognize(['sort'], $combined), "Just need to sort";
ok $m->recognize(['cat_cols', 'sort'], $letters->union($numbers)), "Combine and sort";
ok $m->recognize(['cut_second_col', 'cat_cols', 'sort'], $letters), "Cut numbers, combine and sort";
ok $m->recognize(['cut_first_col', 'cat_cols', 'sort'], $numbers), "Cut numbers, combine and sort";
ok $m->recognize(['cut_first_col', 'cut_second_col', 'cat_cols', 'sort'], $start), "Cut both cols, combine and sort";

ok ! $m->recognize([], $start), "Bad plan";
ok ! $m->recognize(['sort'], $start), "Bad plan";

{
    my @plan = qw(cut_first_col cut_second_col cat_cols sort);
    
    is $m->skippable(\@plan, $start), 0, "Can't skip any";
    is $m->skippable(\@plan, $letters), 1, "Skip cutting letters";
    is $m->skippable(\@plan, $letters->union($numbers)), 2, "Skip cutting letters and numbers";
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

