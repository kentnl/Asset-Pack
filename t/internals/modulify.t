use strict;
use warnings;

use Test::More;
use Asset::Pack;

*modulify = \&Asset::Pack::_modulify;

# ABSTRACT: A test for modulify

is( modulify( 'example.js', 'Prefix' ), 'Prefix::examplejs', "Modulify strips dots" );

done_testing;

