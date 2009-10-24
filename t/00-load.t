#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Pod::Parser::Groffmom' );
}

diag( "Testing Pod::Parser::Groffmom $Pod::Parser::Groffmom::VERSION, Perl $], $^X" );
