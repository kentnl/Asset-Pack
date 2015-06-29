use strict;
use warnings;

use Test::More;

use Asset::Pack qw(module_full_path);

# ABSTRACT: test module_full_path

my %names = (
  'Foo'            => 'Foo.pm',
  'Foo::Bar::B123' => 'Foo/Bar/B123.pm',
);
my @paths = ( 'foo/', '../foo/', '/foo/' );
foreach my $k ( keys %names ) {
  foreach my $p (@paths) {
    my $fp = module_full_path( $k, $p );
    is( $fp, $p . $names{$k}, "$k resolves to the full path as it should" );
  }
}

done_testing;

