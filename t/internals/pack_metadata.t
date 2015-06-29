use strict;
use warnings;

use Test::More;
use Test::Differences qw( eq_or_diff );

# ABSTRACT: Test _pack_metadata

use Asset::Pack;

*pack_metadata = \&Asset::Pack::_pack_metadata;

eq_or_diff( pack_metadata(), '', "No args -> No Meta" );
eq_or_diff( pack_metadata( {} ), '', "Empty hash -> No Meta" );

{
  my $struct = { VERSION => '1.0' };
  my $expected = <<'EOF';
our $VERSION = '1.0';
EOF
  eq_or_diff( pack_metadata($struct), $expected, "VERSION only" );
}

{
  my $struct = { VERSION => '1.0', 'candies' => '5' };
  my $expected = <<'EOF';
our $VERSION = '1.0';
our $METADATA = {
  'candies' => '5'
};
our $candies = $METADATA->{'candies'};
EOF
  eq_or_diff( pack_metadata($struct), $expected, "Extra data = full spec" );
}

{
  my $struct = { 'candies' => '5' };
  my $expected = <<'EOF';
our $METADATA = {
  'candies' => '5'
};
our $candies = $METADATA->{'candies'};
EOF
  eq_or_diff( pack_metadata($struct), $expected, "Extra data w/o version = full spec" );
}
{
  my $struct = { VERSION => '1.0', 'candies' => '5', hard => [] };
  $struct->{'lemons'} = $struct->{'hard'};
  my $expected = <<'EOF';
our $VERSION = '1.0';
our $METADATA = {
  'candies' => '5',
  'hard' => [],
  'lemons' => []
};
$METADATA->{'lemons'} = $METADATA->{'hard'};
our $candies = $METADATA->{'candies'};
our $hard = $METADATA->{'hard'};
our $lemons = $METADATA->{'lemons'};
EOF
  eq_or_diff( pack_metadata($struct), $expected, "Extra data  w/ cycles preserved" );
}

done_testing;
