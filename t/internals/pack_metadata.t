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
    if ( *{ $stash->{$key} }{SCALAR} ) {
      my $value = *{ $stash->{$key} }{SCALAR};
      $stash_contents->{$key} = ${$value} if defined ${$value};
    }
    if ( *{ $stash->{$key} }{ARRAY} ) {
      my $value = *{ $stash->{$key} }{ARRAY};
      $stash_contents->{ '@' . $key } = $value;
    }
    if ( *{ $stash->{$key} }{HASH} ) {
      my $value = *{ $stash->{$key} }{HASH};
      $stash_contents->{ '%' . $key } = $value;
    }
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

use Test::Differences qw( eq_or_diff );

subtest "simple metadata + variables w/ cycle" => sub {
  my $struct = { VERSION => '1.0', 'candies' => '5', hard => [] };
  $struct->{'lemons'} = $struct->{'hard'};

  my $ref = mk_pack( pack_metadata( $struct, [qw( $candies $hard $lemons )] ) );
  my @expected = ( 'VERSION', 'meta', 'candies', 'hard', 'lemons' );

  eq_or_diff( [ sort keys %{$ref} ], [ sort @expected ], 'Only expected vars' );
  is_deeply( $ref->{meta}->{PACKER}, $packer_struct, 'PACKER is expected' );
  is( $ref->{meta}->{candies}, '5', 'candies is expected' );
  is_deeply( $ref->{meta}->{hard},   [], 'hard is an empty array' );
  is_deeply( $ref->{meta}->{lemons}, [], 'lemons is an empty array' );
  is( $ref->{meta}->{hard}, $ref->{meta}->{lemons}, 'hard and lemons share stringified forms( same ref )' );

  is( $ref->{candies}, '5', 'candies is expected' );
  is_deeply( $ref->{hard},   [], 'hard is an empty array' );
  is_deeply( $ref->{lemons}, [], 'lemons is an empty array' );
  is( $ref->{hard}, $ref->{lemons}, 'hard and lemons share stringified forms( same ref )' );

} or diag $last_pack;

subtest "simple metadata + mixed variables w/ cycle" => sub {
  my $struct = { VERSION => '1.0', 'candies' => '5', hard => [ { happy => 1 } ] };
  $struct->{'lemons'} = $struct->{'hard'};

  my $ref = mk_pack( pack_metadata( $struct, [qw( @hard @lemons )] ) );
  note explain $ref;
  my (@expected) = ( 'VERSION', 'meta', '@hard', '@lemons' );
  eq_or_diff( [ sort keys %{$ref} ], [ sort @expected ], 'Only expected vars' );
  is_deeply( $ref->{meta}->{PACKER}, $packer_struct, 'PACKER is expected' );
  is( $ref->{meta}->{candies}, '5', 'candies is expected' );
  is_deeply( $ref->{meta}->{hard},   [ { happy => 1 } ], 'hard is expected' );
  is_deeply( $ref->{meta}->{lemons}, [ { happy => 1 } ], 'lemons is expected' );
  is( $ref->{meta}->{hard}, $ref->{meta}->{lemons}, 'hard and lemons share stringified forms( same ref )' );

  eq_or_diff( $ref->{'@hard'},   [ { happy => 1 } ], 'hard has the expected structure' );
  eq_or_diff( $ref->{'@lemons'}, [ { happy => 1 } ], 'lemons has the expected structure' );
  isnt( $ref->{'@hard'}, $ref->{'@lemons'}, 'hard and lemons dont share a ref' );
  is( $ref->{'@hard'}->[0], $ref->{'@lemons'}->[0], 'hard and lemons share a child' );

} or diag $last_pack;

subtest "simple metadata + self-mixed variables w/ cycle" => sub {
  my $struct = { VERSION => '1.0', 'candies' => '5', hard => [ { happy => 1 } ] };
  $struct->{'lemons'} = $struct->{'hard'};

  my $ref = mk_pack( pack_metadata( $struct, [qw( $lemons @lemons )] ) );
  note explain $ref;
  my (@expected) = ( 'VERSION', 'meta', 'lemons', '@lemons' );
  eq_or_diff( [ sort keys %{$ref} ], [ sort @expected ], 'Only expected vars' );
  is_deeply( $ref->{meta}->{PACKER}, $packer_struct, 'PACKER is expected' );
  is( $ref->{meta}->{candies}, '5', 'candies is expected' );
  is_deeply( $ref->{meta}->{hard},   [ { happy => 1 } ], 'hard expected' );
  is_deeply( $ref->{meta}->{lemons}, [ { happy => 1 } ], 'lemons is expected' );
  is( $ref->{meta}->{hard}, $ref->{meta}->{lemons}, 'hard and lemons share stringified forms( same ref )' );

  eq_or_diff( $ref->{'lemons'},  [ { happy => 1 } ], '$lemons has the expected structure' );
  eq_or_diff( $ref->{'@lemons'}, [ { happy => 1 } ], '@lemons has the expected structure' );
  isnt( $ref->{'lemons'}, $ref->{'@lemons'}, '$lemons and @lemons dont share a ref' );
  is( $ref->{'lemons'}->[0], $ref->{'@lemons'}->[0], '$lemons and @lemons share a child' );

} or diag $last_pack;

subtest "simple metadata + hash variable" => sub {
  my $struct = { VERSION => '1.0', myhash => { happy => 1 } };

  my $ref = mk_pack( pack_metadata( $struct, [qw( %myhash )] ) );
  note explain $ref;
  my (@expected) = ( 'VERSION', 'meta', '%myhash' );
  eq_or_diff( [ sort keys %{$ref} ], [ sort @expected ], 'Only expected vars' );
  is_deeply( $ref->{meta}->{PACKER}, $packer_struct, 'PACKER is expected' );
  is_deeply( $ref->{meta}->{myhash}, { happy => 1 }, 'myhash expected' );

  eq_or_diff( $ref->{'%myhash'}, { happy => 1 }, '%myhash is expected structure' );

} or diag $last_pack;

done_testing;
