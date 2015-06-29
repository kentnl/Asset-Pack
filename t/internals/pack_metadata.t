use strict;
use warnings;

use Test::More;
use Test::Differences qw( eq_or_diff );

# ABSTRACT: Test _pack_metadata

use Asset::Pack;

*pack_metadata = \&Asset::Pack::_pack_metadata;

my $id = 0;

my $packer_struct = {
  name    => 'Asset::Pack',
  version => "$Asset::Pack::VERSION",
};

sub mk_pack {
  my ($pack_code) = @_;
  my $class = "__ANON__::" . $id;
  $id++;
  my $code = qq[package $class; $pack_code;\n 1];
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
  is_deeply( [ sort keys %{$ref} ], [ 'METADATA', 'PACKER' ], 'Only expected vars' );
  is_deeply( $ref->{PACKER}, $packer_struct, 'PACKER is expected' );
};

subtest "empty hash args" => sub {
  my $ref = mk_pack( pack_metadata( {} ) );
  is_deeply( [ sort keys %{$ref} ], [ 'METADATA', 'PACKER' ], 'Only expected vars' );
  is_deeply( $ref->{PACKER}, $packer_struct, 'PACKER is expected' );
};

subtest "version args" => sub {
  my $ref = mk_pack( pack_metadata( { VERSION => '1.0' } ) );
  is_deeply( [ sort keys %{$ref} ], [ 'METADATA', 'PACKER', 'VERSION' ], 'Only expected vars' );
  is_deeply( $ref->{PACKER}, $packer_struct, 'PACKER is expected' );
  is( $ref->{VERSION}, '1.0', 'VERSION is expected' );
};

subtest "simple metadata + version" => sub {
  my $ref = mk_pack( pack_metadata( { VERSION => '1.0', 'candies' => '5' } ) );
  is_deeply( [ sort keys %{$ref} ], [ 'METADATA', 'PACKER', 'VERSION', 'candies' ], 'Only expected vars' );
  is_deeply( $ref->{PACKER}, $packer_struct, 'PACKER is expected' );
  is( $ref->{VERSION}, '1.0', 'VERSION is expected' );
  is( $ref->{candies}, '5',   'candies is expected' );
};

subtest "simple metadata w/o version" => sub {
  my $ref = mk_pack( pack_metadata( { 'candies' => '5' } ) );
  is_deeply( [ sort keys %{$ref} ], [ 'METADATA', 'PACKER', 'candies' ], 'Only expected vars' );
  is_deeply( $ref->{PACKER},  $packer_struct, 'PACKER is expected' );
  is_deeply( $ref->{candies}, '5',            'candies is expected' );
};

subtest "simple metadata w/ cycle" => sub {
  my $struct = { VERSION => '1.0', 'candies' => '5', hard => [] };
  $struct->{'lemons'} = $struct->{'hard'};

  my $ref = mk_pack( pack_metadata($struct) );
  is_deeply( [ sort keys %{$ref} ], [ 'METADATA', 'PACKER', 'VERSION', 'candies', 'hard', 'lemons' ], 'Only expected vars' );
  is_deeply( $ref->{PACKER}, $packer_struct, 'PACKER is expected' );
  is( $ref->{candies}, '5', 'candies is expected' );
  is_deeply( $ref->{hard},   [], 'hard is an empty array' );
  is_deeply( $ref->{lemons}, [], 'lemons is an empty array' );
  is( $ref->{hard}, $ref->{lemons}, 'hard and lemons share stringified forms( same ref )' );
};

done_testing;
