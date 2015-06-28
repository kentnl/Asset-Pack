use 5.010000;
use strict;
use warnings;

package Asset::Pack;

use Path::Tiny qw( path );

our $VERSION = '0.000001';

# ABSTRACT: Easily pack assets into Perl Modules that can be fat-packed

# AUTHORITY

use parent qw(Exporter);
our @EXPORT_OK = qw(
  module_rel_path module_full_path
  pack_asset write_module
);

our @EXPORT = qw(write_module);

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
  my ( $module, $path ) = @_;
  my $content = pack 'u', path($path)->slurp_raw;
  return <<"EOF";
package $module;
our \$content = join q[], *DATA->getlines;
close *DATA;
\$content =~ s/\\s+//g;
\$content = unpack 'u', \$content;
__DATA__
$content
EOF
}

sub write_module {
  my ( $source, $module, $libdir ) = @_;
  my $dest = module_full_path( $module, $libdir );
  $dest->parent->mkpath;    # mkdir
  $dest->spew_utf8( pack_asset( $module, $source ) );
  return;
}

1;
__END__

=head1 SYNOPSIS

    #!/usr/bin/env perl
    use Asset::Pack;
    # lib/MyApp/Asset/FooJS.pm will embed assets/foo.js
    write_module('assets/foo.js','MyApp::Asset::FooJS','lib');

=head1 DESCRIPTION

This module allows you to construct Perl modules containing the content of
arbitrary files, which may then be installed or fat-packed.

In most cases, this module is not what you want, and you should use a
C<File::ShareDir> based system instead, but C<File::ShareDir> based systems are
inherently not fat-pack friendly.

However, if you need embedded, single-file applications, aggregating not only
Perl Modules, but templates, JavaScript and CSS, this tool will make some of
your work easier.

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

=func C<write_module>

  write_module($source, $module, $libdir)

  write_module("./foo.js", "Foo::Bar", "./")
  # ./Foo/Bar.pm now contains a uuencoded copy of foo.js

Given a source asset path, a module name and a library directory, packs the
source into a module named C<$module> and saves it in the right place relative
to C<$libdir>

See L</SYNOPSIS> and try it out!
