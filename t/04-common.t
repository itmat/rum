#!perl
# -*- cperl -*-

use Test::More tests => 11;
use Test::Exception;
use lib "lib";

use strict;
use warnings;
use Log::Log4perl qw(:easy);

BEGIN { 
  use_ok('RUM::Common', qw(getave format_large_int reversesignal spansTotalLength));
}

is(getave("10184-10303"), "10243.5");
is(getave("32004713-32004734",
          "32005767-32005815",
          "32016413-32016461"),
   "32004723.5");

is(format_large_int(1234567890), "1,234,567,890",
   "format large int");


# reversesignal
is(reversesignal("AC"), "GT", "Reverse signal 1");
is(reversesignal("TG"), "CA", "Reverse signal 2");

#spansTotalLength

is(spansTotalLength("1-5, 10-12, 20-30"), 19,
   "spansTotalLength");

is(spansTotalLength("-6"), 7, "spansTotalLength with bad span");
is(spansTotalLength("6-"), -5, "spansTotalLength with bad span");
is(spansTotalLength("-"), 1, "spansTotalLength with bad span");
is(spansTotalLength(""), 0, "spansTotalLength with no span");
