use strict;
use warnings;

use Test::More;

use v5.10;
use MIME::Base64;
use Path::Tiny;
use File::Temp qw(tempdir);
use Asset::Pack qw(module_rel_path module_full_path pack_asset write_module unpack_asset);

{
  my %names = (
    'Foo' => 'Foo.pm',
    'Foo::Bar::B123' => 'Foo/Bar/B123.pm',
  );
  foreach my $k (keys %names) {
    is(module_rel_path($k), $names{$k});
  }
  my @paths = ('foo/', '../foo/', '/foo/');
  foreach my $k (keys %names) {
    foreach my $p (@paths) {
      my $fp = module_full_path($k, $p);
      is($fp, $p . $names{$k});
    }
  }
}

#pack_asset, write_module, unpack_asset
{
  # Create a temporary directory into which we will dump and add it to @INC
  my $tmpdir = tempdir;#(CLEANUP => 1);
  unshift @INC, $tmpdir;
  my %paths = (
    't/pack.t' => 'Test::PackT',
    'README.pod' => 'Test::READMEpod',
    'lib/Asset/Pack.pm' => 'Test::AssetPack',
  );
  foreach my $p (keys %paths) {
    my $content = path($p)->slurp_raw;
    my $encoded = encode_base64($content);
    my $expected = <<EOF
package $paths{$p};
use Asset::Pack;
our \$content = unpack_asset;
__DATA__
$encoded
EOF
;
    is(pack_asset($paths{$p}, $p), $expected);
    write_module($p, $paths{$p}, $tmpdir);
    is(module_full_path($paths{$p}, $tmpdir)->slurp_raw, $expected);
    use_ok($paths{$p});
    {
      no strict 'refs';
      is(${"$paths{$p}::content"}, $content);
	 }
  }
}

done_testing;
