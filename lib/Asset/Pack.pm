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
  my ( $path, $namespace ) = @_;
  $path =~ s/[[^:lower:]]//gi;
  return $namespace . q[::] . $path;
}

sub module_rel_path {
  my ($module) = @_;
  $module =~ s{::}{/}g;
  return "${module}.pm";
}

sub module_full_path {
  my ( $module, $libdir ) = @_;
  $libdir = './lib' if not defined $libdir;
  return path($libdir)->child( module_rel_path($module) );
}

sub pack_asset {
  my ( $module, $path, $metadata ) = @_;
  my $content = pack 'u', path($path)->slurp_raw;
  my $metadata_header = _pack_metadata( $metadata, { add_banned => ['content'] } );

  return <<"EOF";
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

sub pack_index {
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
  $metadata ||= {};
  $metadata->{index} = $index;
  my $index_text = _pack_metadata( $metadata, { add_special => ['index'] } );
  return <<"EOF";
package $module;
$index_text;
1;
EOF

}

sub write_module {
  my ( $source, $module, $libdir, $metadata ) = @_;
  my $dest = module_full_path( $module, $libdir );
  $dest->parent->mkpath;    # mkdir
  $dest->spew_utf8( pack_asset( $module, $source , $metadata ) );
  return;
}

sub write_index {
  my ( $index, $module, $libdir , $metadata ) = @_;
  my $dest = module_full_path( $module, $libdir );
  $dest->parent->mkpath;
  $dest->spew_utf8( pack_index( $module, $index, $metadata ) );
  return;
}

sub find_assets {
  my ( $dir, $ns ) = @_;
  my $assets = path($dir);
  return %{
    $assets->visit(
      sub {
        my ( $path, $state ) = @_;
        return if $path->is_dir;
        my $rel = $path->relative($assets);
        $state->{ modulify( $rel, $ns ) } = $rel;
        return;
      },
      { recurse => 1 },
    );
  };
}

sub find_and_pack {
  my ( $dir, $ns ) = @_;
  my %assets = find_assets( $dir, $ns );
  my ( @ok, @fail, @unchanged );
  while ( my ( $module, $file ) = each %assets ) {
    my $m = path( module_full_path( $module, 'lib' ) );
    my $fd = try { $file->stat->mtime } catch { 0 };
    my $md = try { $m->stat->mtime } catch    { 0 };
    if ( $fd <= $md ) {
      push @unchanged, { module => $m, file => $file };
      next;
    }
    try {
      write_module( $file, $module, 'lib' );
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

sub _pack_metadata {
  my ( $metadata, $config ) = @_;

  $config ||= {};
  $config->{special} ||= ['VERSION'];
  $config->{metadata_name} = 'METADATA' if not exists $config->{metadata_name};
  $config->{banned} ||= [ defined $config->{metadata_name} ? $config->{metadata_name} : () ];
  push @{ $config->{banned} },  @{ $config->{add_banned} }  if $config->{add_banned};
  push @{ $config->{special} }, @{ $config->{add_special} } if $config->{add_special};

  my @headers;
  $metadata->{PACKER} ||= {
    name    => __PACKAGE__,
    version => "$VERSION",
  };

  for my $banned_header ( @{ $config->{banned} } ) {
    next unless exists $metadata->{$banned_header};
    die "Explicit metadata field $banned_header disallowed";
  }

  for my $special_header ( @{ $config->{special} } ) {
    next unless exists $metadata->{$special_header};
    push @headers, _pack_variable( 'our', $special_header, delete $metadata->{$special_header} );
  }

  if ( keys %{$metadata} ) {
    if ( defined $config->{metadata_name} ) {
      push @headers, _pack_variable( 'our', $config->{metadata_name}, $metadata );
      for my $key ( sort keys %{$metadata} ) {
        push @headers, 'our $' . $key . ' = $' . $config->{metadata_name} . '->{\'' . $key . '\'};' . qq[\n];
      }
    }
    else {
      for my $key ( sort keys %{$metadata} ) {
        push @headers, _pack_variable( 'our', $key, $metadata->{$key} );
      }
    }
  }
  return join qq[], @headers;
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
