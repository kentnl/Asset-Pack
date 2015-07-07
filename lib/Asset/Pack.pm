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
our @EXPORT_OK = qw();
our @EXPORT    = qw(write_module write_index find_and_pack);

sub _modulify {
  my ( $path, $namespace ) = @_;
  $path =~ s/[^[:lower:]]//gi;
  return $namespace . q[::] . $path;
}

sub _module_rel_path {
  my ($module) = @_;
  $module =~ s{::}{/}g;
  return "${module}.pm";
}

sub _module_full_path {
  my ( $module, $libdir ) = @_;
  $libdir = './lib' if not defined $libdir;
  return path($libdir)->child( _module_rel_path($module) );
}

sub _pack_asset {
  my ( $module, $path, $metadata ) = @_;
  my $content = pack 'u', path($path)->slurp_raw;
  my $metadata_header = _pack_metadata($metadata);

  return <<"EOF";
use strict;
use warnings;
package $module;
$metadata_header
our \$content = join q[], <DATA>;
close *DATA;
\$content =~ s/\\s+//g;
\$content = unpack 'u', \$content;
1;
__DATA__
$content
EOF
}

sub _pack_index {
  my ( $module, $index, $metadata ) = @_;
  $index = { %{ $index || {} } };    # Shallow clone.
  for my $key ( keys %{$index} ) {
    next unless ref $index->{$key};
    if ( eval { $index->{$key}->isa('Path::Tiny') } ) {
      $index->{$key} = "$index->{$key}";
      next;
    }
    die "Unsupported ref value in index for key $key: $index->{$key}";
  }
  my $metadata_header = _pack_metadata($metadata);
  my $index_text = _pack_variable( 'our', 'index', $index );
  return <<"EOF";
package $module;
$metadata_header;
$index_text;
1;
EOF

}

sub write_module {
  my ( $source, $module, $libdir, $metadata ) = @_;
  my $dest = _module_full_path( $module, $libdir );
  $dest->parent->mkpath;    # mkdir
  $dest->spew_utf8( _pack_asset( $module, $source, $metadata ) );
  return;
}

sub write_index {
  my ( $index, $module, $libdir, $metadata ) = @_;
  my $dest = _module_full_path( $module, $libdir );
  $dest->parent->mkpath;
  $dest->spew_utf8( _pack_index( $module, $index, $metadata ) );
  return;
}

sub _find_assets {
  my ( $dir, $ns ) = @_;
  my $assets = path($dir);
  return %{
    $assets->visit(
      sub {
        my ( $path, $state ) = @_;
        return if $path->is_dir;
        my $rel = $path->relative($assets);
        $state->{ _modulify( $rel, $ns ) } = $rel;
        return;
      },
      { recurse => 1 },
    );
  };
}

sub find_and_pack {
  my ( $dir, $ns, $libdir ) = @_;
  my %assets = _find_assets( $dir, $ns );
  my ( @ok, @fail, @unchanged );
  while ( my ( $module, $file ) = each %assets ) {
    my $m = path( _module_full_path( $module, $libdir ) );
    my $fd = try { $file->stat->mtime } catch { 0 };
    my $md = try { $m->stat->mtime } catch    { 0 };
    if ( $fd <= $md ) {
      push @unchanged, { module => $m, file => $file };
      next;
    }
    try {
      write_module( $file, $module, $libdir );
      push @ok, { module => $m, file => $file };
    }
    catch {
      push @fail, { module => $m, file => $file, error => $_ };
    };
  }
  return { ok => \@ok, fail => \@fail, unchanged => \@unchanged };
}

sub _pack_variable {
  my ( $context, $varname, $content ) = @_;
  require Data::Dumper;
  my $dumper = Data::Dumper->new( [$content], [$varname] );
  $dumper->Purity(1)->Sortkeys(1);
  $dumper->Terse(0)->Indent(1);
  return sprintf '%s %s', $context, $dumper->Dump();
}

# _pack_metadata($metadata,) returns evalable code creating a
# collection of `our` variables.
#
# Importantly, it sticks most of the content in a top level variable called $meta,
# and creates `our $VERSION` when VERSION is in metadata.
#
# Additionally, a default value of PACKER = { ... } is injected into $meta.

sub _pack_metadata {
  my ( $metadata, ) = @_;

  $metadata->{PACKER} ||= {
    name    => __PACKAGE__,
    version => "$VERSION",
  };
  my @headers;
  if ( exists $metadata->{'VERSION'} ) {
    push @headers, _pack_variable( 'our', 'VERSION', delete $metadata->{'VERSION'} );
  }
  push @headers, _pack_variable( 'our', 'meta', $metadata );
  return join q[], @headers;
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
a human (or analyzed if it fails as part of a build).

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

=func C<find_and_pack>

  find_and_pack( $root_dir, $namespace_prefix, $libdir ) -> Hash

Creates copies of all the contents of C<$root_dir> and constructs
( or reconstructs ) the relevant modules using C<$namespace_prefix>
and stores them in C<$libdir> ( which defaults to C<./lib/> )

Returns a hash detailing operations and results:

  {
    ok        => [ { module => ..., file => ... }, ... ],
    unchanged => [ { module => ..., file => ... }, ... ],
    fail      => [ { module => ..., file => ..., error => ... }, ... ],
  }
