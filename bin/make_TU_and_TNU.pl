#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script::MakeTuAndTnu;
RUM::Script::MakeTuAndTnu->main;


