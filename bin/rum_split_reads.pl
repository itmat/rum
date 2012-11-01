#!/usr/bin/perl

# Written by Gregory R. Grant
# Universiity of Pennsylvania, 2010

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script::SplitReads;
RUM::Script::SplitReads->main;

