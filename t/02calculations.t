use Test;
use Time::Timecode;

require 't/util.pl';

BEGIN { plan tests => 31 }

my $tc = Time::Timecode->new(30); #total frames

#check method alias
ok($tc->hh, 0);
ok($tc->mm, 0);
ok($tc->ss, 1);
ok($tc->ff, 0);
ok($tc->total_frames, 30);

$tc = Time::Timecode->new(1, 10, 20);
hmsf_ok($tc, 1, 10, 20, 0);
ok($tc->total_frames, 126600);

$tc = Time::Timecode->new(1, 10, 20, 29);
hmsf_ok($tc, 1, 10, 20, 29);
ok($tc->total_frames, 126629);

$tc = Time::Timecode->new($tc->total_frames);
hmsf_ok($tc, 1, 10, 20, 29);
ok($tc->total_frames, 126629);

#compare drop/non-drop calculations
$tc = Time::Timecode->new(0, 1, 0, 2, { dropframe => 1 });
hmsf_ok($tc, 0, 1, 0, 2);
ok($tc->total_frames, 1800);

$tc = Time::Timecode->new(0, 1, 0, 2, { dropframe => 0 });
ok($tc->total_frames, 1802);

$tc = Time::Timecode->new(1387252, { dropframe => 1 });
hmsf_ok($tc, 12, 51, 28, 0);

$tc = Time::Timecode->new(12, 51, 28, { dropframe => 1 });
ok($tc->total_frames, 1387252);
