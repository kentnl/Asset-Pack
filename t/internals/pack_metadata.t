use strict;
use warnings;

use Test::More;

# ABSTRACT: Test _pack_metadata

use Asset::Pack;

*pack_metadata = \&Asset::Pack::_pack_metadata;

my $id = 0;

my $packer_struct = {
  name    => 'Asset::Pack',
  version => "$Asset::Pack::VERSION",
};
my $last_pack;

sub mk_pack {
  my ($pack_code) = @_;
  my $class = "__ANON__::" . $id;
  $id++;
  my $code = qq[use strict; use warnings; \npackage $class;\n$pack_code;\n1;\n];
  $last_pack = $code;
  local $@;
  eval $code or die "Did not get true return, $@";
  my $stash_contents = {};
  no strict 'refs';
  my $stash = \%{ $class . '::' };

  for my $key ( keys %{$stash} ) {
    local $@;
    eval {
      my $value = ${ $stash->{$key} };
      $stash_contents->{$key} = $value;
      1;
    } and next;
    warn "$@ while scalarizing $key";
  }
  return $stash_contents;
}

subtest "empty args" => sub {
  my $ref = mk_pack( pack_metadata() );
  is_deeply( [ sort keys %{$ref} ], ['meta'], 'Only expected vars' );
  is_deeply( $ref->{meta}->{PACKER}, $packer_struct, 'PACKER is expected' );
} or diag $last_pack;

subtest "empty hash args" => sub {
  my $ref = mk_pack( pack_metadata( {} ) );
  is_deeply( [ sort keys %{$ref} ], ['meta'], 'Only expected vars' );
  is_deeply( $ref->{meta}->{PACKER}, $packer_struct, 'PACKER is expected' );
} or diag $last_pack;

subtest "version args" => sub {
  my $ref = mk_pack( pack_metadata( { VERSION => '1.0' } ) );
  is_deeply( [ sort keys %{$ref} ], [ 'VERSION', 'meta' ], 'Only expected vars' );
  is_deeply( $ref->{meta}->{PACKER}, $packer_struct, 'PACKER is expected' );
  is( $ref->{VERSION}, '1.0', 'VERSION is expected' );
  ok( !exists $ref->{meta}->{VERSION}, 'VERSION not in METADATA' );
} or diag $last_pack;

subtest "simple metadata + version" => sub {
  my $ref = mk_pack( pack_metadata( { VERSION => '1.0', 'candies' => '5' } ) );
  is_deeply( [ sort keys %{$ref} ], [ 'VERSION', 'meta' ], 'Only expected vars' );
  is_deeply( $ref->{meta}->{PACKER}, $packer_struct, 'PACKER is expected' );
  is( $ref->{VERSION},         '1.0', 'VERSION is expected' );
  is( $ref->{meta}->{candies}, '5',   'candies is expected' );
} or diag $last_pack;

subtest "simple metadata w/o version" => sub {
  my $ref = mk_pack( pack_metadata( { 'candies' => '5' } ) );
  is_deeply( [ sort keys %{$ref} ], ['meta'], 'Only expected vars' );
  is_deeply( $ref->{meta}->{PACKER},  $packer_struct, 'PACKER is expected' );
  is_deeply( $ref->{meta}->{candies}, '5',            'candies is expected' );
} or diag $last_pack;

subtest "simple metadata w/ cycle" => sub {
  my $struct = { VERSION => '1.0', 'candies' => '5', hard => [] };
  $struct->{'lemons'} = $struct->{'hard'};

  my $ref = mk_pack( pack_metadata($struct) );
  is_deeply( [ sort keys %{$ref} ], [ 'VERSION', 'meta' ], 'Only expected vars' );
  is_deeply( $ref->{meta}->{PACKER}, $packer_struct, 'PACKER is expected' );
  is( $ref->{meta}->{candies}, '5', 'candies is expected' );
  is_deeply( $ref->{meta}->{hard},   [], 'hard is an empty array' );
  is_deeply( $ref->{meta}->{lemons}, [], 'lemons is an empty array' );
  is( $ref->{meta}->{hard}, $ref->{meta}->{lemons}, 'hard and lemons share stringified forms( same ref )' );
} or diag $last_pack;

done_testing;
