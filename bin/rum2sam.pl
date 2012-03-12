#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::RumToSam");
