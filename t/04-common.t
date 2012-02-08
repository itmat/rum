#!perl -T
# -*- cperl -*-

use Test::More tests => 4;
use Test::Exception;
use lib "lib";

use strict;
use warnings;
use Log::Log4perl qw(:easy);

BEGIN { 
  use_ok('RUM::Common', qw(getave format_large_int));
}

is(getave("10184-10303"), "10243.5");
is(getave("32004713-32004734",
          "32005767-32005815",
          "32016413-32016461"),
   "32004723.5");

is(format_large_int(1234567890), "1,234,567,890",
   "format large int");
