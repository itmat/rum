#!perl
# -*- cperl -*-

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Test::More;

use RUM::Config;
use RUM::Platform;

BEGIN { 
    eval "use Test::Exception";
    plan skip_all => "Test::Exception needed" if $@;
    plan tests => 3;
}

throws_ok { RUM::Platform->new->preprocess } qr/not implemented/i, "preprocess not implemented";
throws_ok { RUM::Platform->new->process } qr/not implemented/i, "process not implemented";
throws_ok { RUM::Platform->new->postprocess } qr/not implemented/i, "postprocess not implemented";
