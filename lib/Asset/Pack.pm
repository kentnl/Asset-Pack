use 5.006;    # our
use strict;
use warnings;

package Asset::Pack;

use Path::Tiny qw( path );
use Try::Tiny qw( try catch );

our $VERSION = '0.000001';

# ABSTRACT: Easily pack assets into Perl Modules that can be fat-packed

# AUTHORITY

use parent qw(Exporter);
our @EXPORT_OK = qw(
  modulify
  module_rel_path module_full_path
  pack_asset write_module
  find_assets find_and_pack
  pack_index write_index
);

our @EXPORT = qw(write_module find_and_pack);

sub modulify {
  my ($path, $namespace) = @_;
  $path =~ s/[^a-z]//gi;
  $namespace . "::" . $path;
}

sub module_rel_path {
  my ($module) = @_;
  $module =~ s{::}{/}g;
  return "${module}.pm";
}

sub module_full_path {
  my ($module, $libdir) = @_;
  return path($libdir)->child(module_rel_path($module));
}

sub pack_asset {
  my ( $module, $path, $version ) = @_;
  my $content           = pack 'u', path($path)->slurp_raw;
  my $packer            = __PACKAGE__ . ' version ' . $VERSION;
  my $version_statement = q[];
  if ( defined $version ) {
    $version_statement = sprintf q[our $VERSION = '%s';], $version;
  }
  return <<"EOF";
package $module;
# Generated from $path by $packer
$version_statement
our \$content = join q[], <DATA>;
close *DATA;
\$content =~ s/\\s+//g;
\$content = unpack 'u', \$content;
1;
__DATA__
$content
EOF
}

sub pack_index {
  my ( $module, $index ) = @_;
  require Data::Dumper;
  for my $key ( keys %{$index} ) {
    next unless ref $index->{$key};
    if ( eval { $index->{$key}->isa('Path::Tiny') } ) {
      $index->{$key} = "$index";
      next;
    }
    die "Unsupported ref value in index for key $key: $index->{$key}";
  }
  my $index_text =
    Data::Dumper->new( [$index], ['index'] )->Purity(1)->Sortkeys(1)->Terse(0)->Indent(1)->Dump();

  my $packer = __PACKAGE__ . ' version ' . $VERSION;
  return <<"EOF";
package $module;
# Generated index by $packer
our $index_text;
1;
EOF

}

sub write_module {
  my ( $source, $module, $libdir ) = @_;
  my $dest = module_full_path( $module, $libdir );
  $dest->parent->mkpath;    # mkdir
  $dest->spew_utf8( pack_asset( $module, $source ) );
  return;
}

sub write_index {
  my ( $index, $module, $libdir ) = @_;
  my $dest = module_full_path( $module, $libdir );
  $dest->parent->mkpath;
  $dest->spew_utf8( pack_index( $module, $index ) );
  return;
}

sub find_assets {
  my ( $dir, $ns ) = @_;
  my $assets = path($dir);
  %{
    $assets->visit(
      sub {
        my ( $path, $state ) = @_;
        return if $path->is_dir;
        my $rel = $path->relative($assets);
        $state->{ modulify( $rel, $ns ) } = $rel;
        return;
      },
      { recurse => 1 }
    )
  };
}

sub find_and_pack {
  my ( $dir, $ns ) = @_;
  my %assets = find_assets( $dir, $ns );
  my $exitstatus;
  while ( my ( $module, $file ) = each %assets ) {
    my $m = path( module_full_path( $module, 'lib' ) );
    my $fd = try { $file->stat->mtime } catch { 0 };
    my $md = try { $m->stat->mtime } catch    { 0 };
    if ( $fd > $md ) {
      try {
        write_module( $file, $module, 'lib' );
        print "$m updated from $file\n";
      }
      catch {
        print "Failed updating module $m: $_\n";
        $exitstatus++;
      }
    }
    else {
      print "$m is up to date\n";
    }
  }
  return $exitstatus;
}

1;
__END__

=head1 SYNOPSIS

    #!/usr/bin/env perl
    use Asset::Pack;
    # lib/MyApp/Asset/FooJS.pm will embed assets/foo.js
    write_module('assets/foo.js','MyApp::Asset::FooJS','lib');
    # Or better still, this discovers them all and namespaces under MyApp::Asset
    find_and_pack('assets', 'MyApp::Asset");
    # It also writes MyApp::Asset which is an index file

=head1 DESCRIPTION

This module allows you to construct Perl modules containing the content of
arbitrary files, which may then be installed or fat-packed.

In most cases, this module is not what you want, and you should use a
C<File::ShareDir> based system instead, but C<File::ShareDir> based systems are
inherently not fat-pack friendly.

However, if you need embedded, single-file applications, aggregating not only
Perl Modules, but templates, JavaScript and CSS, this tool will make some of
your work easier.

If anything fails it throws an exception. This is meant for scripts that will be tended by
a human (or analysed if it fails as part of a build).

=func C<module_rel_path>

  module_rel_path(module) -> file_path (string)

  module_rel_path("Foo::Bar") # "Foo/Bar.pm"

Turns a module name (e.g. 'Foo::Bar') into a file path relative to a library
directory root

=func C<module_full_path>

  module_full_path(module, libdir) -> file_path (string)

  module_full_path("Foo::Bar", "./") # "./Foo/Bar.pm"

Turns a module name and a library directory into a file path

=func C<pack_asset>

  pack_asset($module, $path) -> byte_string

  pack_asset("Foo::Bar", "./foo.js") # "ZnVuY3Rpb24oKXt9"

Given a module name and the path of an asset to be packed, returns the new
module with the content packed into the data section

=func C<pack_index>

  pack_index($module, \%index) -> byte string

  pack_asset("Foo::Index", { "Some::Name" => "foo.js" });

Creates the contents for an asset index

=func C<write_module>

  write_module($source, $module, $libdir)

  write_module("./foo.js", "Foo::Bar", "./")
  # ./Foo/Bar.pm now contains a uuencoded copy of foo.js

Given a source asset path, a module name and a library directory, packs the
source into a module named C<$module> and saves it in the right place relative
to C<$libdir>

See L</SYNOPSIS> and try it out!

=func C<write_index>

  write_index($index, $module, $libdir )

  write_index({ "A" => "X.js" }, "Foo::Bar", "./");

Creates a file index.
