#!perl
# -*- cperl -*-

use strict;
use warnings;
use autodie;

use Test::More tests => 3;
use lib "lib";

use RUM::SamIO;

is_deeply(RUM::SamIO->flag_descriptions(0x1), 
    ["template having multiple segments in sequencing"],
    "0x1");

is_deeply(RUM::SamIO->flag_descriptions(0x40), 
    ["the first segment in the template"],
    "0x40");

is_deeply(RUM::SamIO->flag_descriptions(0x2 | 0x4 | 0x100),
      ["each segment properly aligned according to the aligner",
       "segment unmapped",
       "secondary alignment"],
      "0x100");

