#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'RUM::Script' ) || print "Bail out!\n";
}

diag( "Testing RUM $RUM::Script::VERSION, Perl $], $^X" );
