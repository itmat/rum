#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 1;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Workflow qw(make_paths report);
use RUM::TestUtils qw(:all);

our $ROOT = "$Bin/../_testing";
our $TEST_DATA_TARBALL   = "$ROOT/rum-test-data.tar.gz";
download_test_data($TEST_DATA_TARBALL);
