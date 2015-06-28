use strict;
use warnings;

use Test::More;

use 5.010000;
use Path::Tiny;
use File::Temp qw(tempdir);
use Asset::Pack qw(module_rel_path module_full_path pack_asset write_module);
use Test::Differences qw( eq_or_diff );
{
  my %names = (
    'Foo' => 'Foo.pm',
    'Foo::Bar::B123' => 'Foo/Bar/B123.pm',
  );
  note "Testing module_rel_path";
  foreach my $k ( keys %names ) {
    is( module_rel_path($k), $names{$k}, "$k resolves to where it should" );
  }
  my @paths = ( 'foo/', '../foo/', '/foo/' );
  note "Testing module_full_path";
  foreach my $k ( keys %names ) {
    foreach my $p (@paths) {
      my $fp = module_full_path( $k, $p );
      is( $fp, $p . $names{$k}, "$k resolves to the full path as it should" );
    }
  }
}

#pack_asset, write_module, unpack_asset
note "Testing write_module, pack_asset, and module-self-unpack";
{
  # Create a temporary directory into which we will dump and add it to @INC
  my $tmpdir = tempdir;#(CLEANUP => 1);
  unshift @INC, $tmpdir;
  my %paths = (
    't/pack.t' => 'Test::PackT',
    'LICENSE' => 'Test::LICENSE',
    'lib/Asset/Pack.pm' => 'Test::AssetPack',
  );
  foreach my $p (keys %paths) {
    my $content = path($p)->slurp_raw;
    my $encoded = pack 'u', $content;
    my $expected = <<EOF
package $paths{$p};
our \$content = join q[], *DATA->getlines;
\$content =~ s/\\s+//g;
\$content = unpack 'u', \$content;
__DATA__
$encoded
EOF
      ;
    eq_or_diff( pack_asset( $paths{$p}, $p ), $expected, "Packed in-memory content for $p" );
    write_module( $p, $paths{$p}, $tmpdir );
    eq_or_diff( module_full_path( $paths{$p}, $tmpdir )->slurp_raw, $expected, "Packed on-disk content for $p" );
    use_ok( $paths{$p} );
    {
      no strict 'refs';
      eq_or_diff( ${"$paths{$p}::content"}, $content, "Loaded and decoded copy of $p" );
    }
  }
}

done_testing;
