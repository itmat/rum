#!perl

use Test::More tests => 1;

BEGIN {
    use_ok( 'RUM::Pipeline' ) || print "Bail out!\n";
}

diag( "Testing RUM $RUM::Pipeline::VERSION, Perl $], $^X" );
