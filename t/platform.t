#!perl
# -*- cperl -*-

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More tests => 3;

use RUM::Config;
use RUM::Directives;
use RUM::Platform;
use Test::Exception;

throws_ok { RUM::Platform->new->preprocess } qr/not implemented/i, "preprocess not implemented";
throws_ok { RUM::Platform->new->process } qr/not implemented/i, "process not implemented";
throws_ok { RUM::Platform->new->postprocess } qr/not implemented/i, "postprocess not implemented";
