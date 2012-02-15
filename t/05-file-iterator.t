#!perl -T
# -*- cperl -*-

use Test::More tests => 7;
use Test::Exception;
use lib "lib";

use strict;
use warnings;
use Log::Log4perl qw(:easy);

BEGIN { 
  use_ok('RUM::FileIterator', qw(file_iterator))
}