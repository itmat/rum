#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 1;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use_ok("RUM::Script::RumToQuantifications");
use RUM::TestUtils;

