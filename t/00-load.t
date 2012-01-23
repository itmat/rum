#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'RUM::Index' ) || print "Bail out!\n";
}

diag( "Testing RUM::Index $RUM::Index::VERSION, Perl $], $^X" );
