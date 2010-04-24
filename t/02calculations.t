use Test;
use Time::Timecode;

require 't/util.pl';

BEGIN { plan tests => 68 }

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

$tc = Time::Timecode->new(29) + Time::Timecode->new(1);
hmsf_ok($tc, 0, 0, 1, 0);

#results get their settings from the LHS
$tc = Time::Timecode->new(1800, { dropframe => 1 }) + Time::Timecode->new(1);
ok($tc->is_dropframe);
hmsf_ok($tc, 0, 1, 0, 3);

$tc = Time::Timecode->new(24, { fps => 25 }) + Time::Timecode->new(1);
ok($tc->fps, 25);
hmsf_ok($tc, 0, 0, 1, 0);

$tc = '12:00:00:00' - Time::Timecode->new(1, 0, 0, 1);
hmsf_ok($tc, 10, 59, 59, 29);

$tc =  Time::Timecode->new(1, 0, 10) - 1;
hmsf_ok($tc, 1, 0, 9, 29);

eval { $tc = Time::Timecode->new(1) - 100 };
ok($@);

$tc =  Time::Timecode->new(0, 1, 0) * Time::Timecode->new(0, 0, 5, 25, { dropframe => 1 });
ok(!$tc->is_dropframe);
hmsf_ok($tc, 2, 55, 0, 0);

$tc =  31 / Time::Timecode->new(16);
hmsf_ok($tc, 0, 0, 0, 1);

$tc =  Time::Timecode->new(1800) / 3600;
hmsf_ok($tc, 0, 0, 0, 0);

#hours > 99
eval { $tc =  Time::Timecode->new(1) * 2000000000000000000 };
ok($@);