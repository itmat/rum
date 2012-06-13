#!perl
# -*- cperl -*-

use Test::More tests => 23;
use lib "lib";

use strict;
use warnings;

use RUM::Iterator;

my $it = RUM::Iterator->new([3, 2, 1]);
is $it->(), 3;
is $it->(), 2;
is $it->(), 1;
is $it->(), undef;

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

$it = RUM::Iterator->new([3, 2, 1])->imap(sub { $_[0] * 2 });
is $it->(), 6;
is $it->(), 4;
is $it->(), 2;
is $it->(), undef;

$it = RUM::Iterator->new([7,6,5,4,3,2,1])->igrep(sub { ($_[0] % 2) == 0  });
is $it->(), 6;
is $it->(), 4;
is $it->(), 2;
is $it->(), undef;

$it = RUM::Iterator->new([1,2,3])->append(RUM::Iterator->new([4,5,6]));

is_deeply $it->to_array, [1,2,3,4,5,6], "append";
