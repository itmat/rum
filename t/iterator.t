#!perl
# -*- cperl -*-

use Test::More tests => 28;
use lib "lib";

use strict;
use warnings;

use RUM::Iterator;

my $it = RUM::Iterator->new([3, 2, 1]);
is $it->next_val, 3;
is $it->next_val, 2;
is $it->next_val, 1;
is $it->next_val, undef;

$it = RUM::Iterator->new([5, 4, 3, 2, 1])->peekable;

is $it->peek, 5;
is $it->peek, 5;
is $it->peek(2), 3;
is $it->peek, 5;
is $it->take, 5;
is $it->take, 4;
is $it->take, 3;
is $it->peek, 2;

sub same_first_char {
    substr($_[0], 0, 1) eq substr($_[1], 0, 1);
}

$it = RUM::Iterator->new(['apple', 'aardvark', 'angus',
                          'beagle', 'bear', 'banana',
                          'cat', 'cot', 'calm'])->group_by(\&same_first_char);

is_deeply $it->next_val->to_array, ['apple', 'aardvark', 'angus'], "First group";
is_deeply $it->next_val->to_array, ['beagle', 'bear', 'banana'], "Second group";
is_deeply $it->next_val->to_array, ['cat', 'cot', 'calm'], "Second group";

$it = RUM::Iterator->new(['apple', 'aardvark', 'angus',
                          'beagle', 'bear', 'banana',
                          'cat', 'cot', 'calm'])->group_by(
                              \&same_first_char,
                              sub { shift });

is_deeply $it->next_val, ['apple', 'aardvark', 'angus'], "First group";
is_deeply $it->next_val, ['beagle', 'bear', 'banana'], "Second group";
is_deeply $it->next_val, ['cat', 'cot', 'calm'], "Second group";

$it = RUM::Iterator->new([3, 2, 1])->imap(sub { $_[0] * 2 });
is $it->next_val, 6;
is $it->next_val, 4;
is $it->next_val, 2;
is $it->next_val, undef;

$it = RUM::Iterator->new([7,6,5,4,3,2,1])->igrep(sub { ($_[0] % 2) == 0  });
is $it->next_val, 6;
is $it->next_val, 4;
is $it->next_val, 2;
is $it->next_val, undef;

$it = RUM::Iterator->new([1,2,3])->append(RUM::Iterator->new([4,5,6]));
is_deeply $it->to_array, [1,2,3,4,5,6], "append";

$it = RUM::Iterator->new([1,2,3])->append(RUM::Iterator->new([4,5,6]),
                                          RUM::Iterator->new([7,8,9]));
is_deeply $it->to_array, [1,2,3,4,5,6,7,8,9], "append multi";

{
    my $twos   = RUM::Iterator->new([2,4,6,8,10,12])->peekable;
    my $threes = RUM::Iterator->new([3,6,9,12])->peekable;
    my $merged = $twos->merge(sub { $_[0] <=> $_[1] }, $threes);
    is_deeply $merged->to_array, [2,3,4,6,6,8,9,10,12,12], "merge";
}


is 15, RUM::Iterator->new([1,2,3,4,5])->ireduce(sub { $a + $b });
is 24, RUM::Iterator->new([2,3,4])->ireduce(sub { $a * $b }, 1);
