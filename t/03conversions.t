use Test;
use Time::Timecode;

require 't/util.pl';

BEGIN { plan tests => 26 }

my $tc = Time::Timecode->new(0,1,0,2, { dropframe => 1 })->to_non_dropframe;
ok($tc->fps, 30);
hmsf_ok($tc,0,1,0,0);
ok($tc->total_frames, 1800);

$tc = Time::Timecode->new(0,1,0)->to_dropframe;
hmsf_ok($tc,0,1,0,2);
ok($tc->total_frames, 1800);

$tc = $tc->convert(24);
ok($tc->fps, 24);
ok(!$tc->is_dropframe);
ok($tc->total_frames, 1800);
hmsf_ok($tc,0,1,15,0);

$tc = $tc->convert(30, { dropframe => 1, frame_delimiter => '.' });
ok($tc->fps, 30);
hmsf_ok($tc,0,1,0,2);
ok($tc->total_frames, 1800);
ok($tc->is_dropframe);
ok($tc->to_string, '00:01:00.02');
