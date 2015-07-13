use strict;
use warnings;

use Test::More;
use Test::Requires { "App::FatPacker" => '0.0009017' }; # Minimum required for fatpack_file
use Test::TempDir::Tiny qw( tempdir );
use Path::Tiny qw( path cwd );
use Asset::Pack qw( find_and_pack );

# ABSTRACT: Test interop with App::FatPacker

my $temp = tempdir('source_tree');
my $cwd  = cwd();
END { chdir $cwd }

path( $temp, 'assets' )->mkpath;
path( $temp, 'lib' )->mkpath;
path( $temp, 'bin' )->mkpath;

path( $temp, 'bin', 'myscript.pl' )->spew_raw(<<'EOF');
use strict;
use warnings;

package myscript;

use Test::X::FindAndPack::examplejs;

sub value {
  return $Test::X::FindAndPack::examplejs::content;
}
1;
EOF

path( $temp, 'assets', 'example.js' )->spew_raw(<<'EOF');
( function() {
  alert("this is javascript!");
} )();
EOF

my $layout = find_and_pack( path( $temp, 'assets' ), 'Test::X::FindAndPack', path( $temp, 'lib' ), );

my $packer = App::FatPacker->new();

chdir $temp;

my $content = $packer->fatpack_file( path( $temp, 'bin', 'myscript.pl' ) );
my $target = path( $temp, 'bin', 'myscript.fatpacked.pl' );

$target->spew_raw($content);

ok( do "$target", "Sourcing fatpacked script works" );

can_ok( 'myscript', 'value' );

is( myscript->value, path( $temp, 'assets', 'example.js' )->slurp_raw(), "Content from fatpacked script ok" );

done_testing;

