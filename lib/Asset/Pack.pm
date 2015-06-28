package Asset::Pack;

use v5.10;
use Path::Tiny;
use MIME::Base64;

our $VERSION = '0.000001';

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
  module_rel_path module_full_path
  pack_asset write_module unpack_asset
);

our @EXPORT = qw(write_module unpack_asset);

sub module_rel_path {
  my ($module) = @_;
  $module =~ s(::)(/)g;
  return "${module}.pm";
}

sub module_full_path {
  my ($module, $libdir) = @_;
  return path($libdir)->child(module_rel_path($module));
}

sub pack_asset {
  my ($module, $path) = @_;
  my $content = encode_base64(path($path)->slurp_raw);
  return <<EOF;
package $module;
use Asset::Pack;
our \$content = unpack_asset;
__DATA__
$content
EOF
}

sub write_module {
  my ($source, $module, $libdir) = @_;
  my $dest = module_full_path($module, $libdir);
  $dest->parent->mkpath; # mkdir
  $dest->spew_utf8(pack_asset($module, $source));
}

sub unpack_asset {
  my $caller = caller;
  my $fh = \*{"${caller}::DATA"};
  my $content = join("", $fh->getlines);
  $content =~ s/\s+//g;
  return decode_base64($content);
}

1;
__END__

=head1 NAME

Asset::Pack - Easily pack assets into perl modules that can be fatpacked

=head1 SYNOPSIS

    #!/usr/bin/env perl
    use Asset::Pack;
    # lib/MyApp/Asset/FooJS.pm will embed assets/foo.js
    write_module('assets/foo.js' 'MyApp::Asset::FooJS' 'lib');

=head1 WHY?

Because I had to write it anyway to make L<DB::Crud> be deployable as a script

I'm using it to embed templates, javascript and css inside modules which are then
fatpacked into a single script. It's a horrible hack, caveat emptor etc.

=head1 SHOULD I USE THIS?

Probably not. It's really not designed to be used except for in fatpacked scripts
If you don't know what a fatpacked script is, you really shouldn't.

=head1 NOTES

Generated files are dependent on the Asset::Pack module. I might remove this dep in future
but it's not a concern for me for the project I wrote this for. Patches welcome.

=head1 FUNCTIONS

=head2 module_rel_path(module) -> file_path (string)

Turns a module name (e.g. 'Foo::Bar') into a file path relative to a library directory root

=head2 module_full_path(module, libdir) -> file_path (string)

Turns a module name and a library directory into a file path

=head2 pack_asset($module, $path) -> byte_string

Given a module name and the path of an asset to be packed, returns the new module with the
content packed into the data section

=head2 write_module($source, $module, $libdir)

Given a source asset path, a module name and a library directory, packs the source into a module
named C<$module> and saves it in the right place relative to C<$libdir>

See 'synopsis' and try it out!

=head2 unpack_asset(FH) -> byte_string

FH is assumed to be DATA. Please pass in DATA
