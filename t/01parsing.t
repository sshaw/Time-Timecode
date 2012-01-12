use Test;
use Time::Timecode;

require 't/util.pl';

BEGIN { plan tests => 45 }

#parse non-dropframe
my $tc = Time::Timecode->new('01:02:03:04');
hmsf_ok($tc, 1, 2, 3, 4);
ok(!$tc->is_dropframe);
ok($tc->to_string, '01:02:03:04');

#parse dropframe
$tc = Time::Timecode->new('00:01:00.02');
hmsf_ok($tc, 0, 1, 0, 2);
ok($tc->is_dropframe);
ok($tc->to_string, '00:01:00.02');
$tc = Time::Timecode->new('10:00:00;22');
hmsf_ok($tc, 10, 0, 0, 22);
ok($tc->is_dropframe);

# Normally a dropframe frame delimiter makes the timecode dropframe 
$tc = Time::Timecode->new('00:01:00.02', { dropframe => 0 });
ok(!$tc->is_dropframe);
ok($tc->total_frames, 1802);

#parse dropframe and recreate with delimiter char
$tc = Time::Timecode->new('00:01:00;02', { delimiter => ',' });
hmsf_ok($tc, 0, 1, 0, 2);
#should still have dropframe delimiter
ok($tc->to_string, '00,01,00;02');

#parse with delimiter char
$tc = Time::Timecode->new('00,22,19;00', { delimiter => ','});
hmsf_ok($tc, 0, 22, 19, 0);
#should still have dropframe delimiter
ok($tc->to_string, '00,22,19;00');

#parse and recreate with frame_delimiter char
$tc = Time::Timecode->new('01:02:03:15', { frame_delimiter => '+' });

######
#ok($tc->to_string, '00:01:01+15');
#ok($tc->to_string('%02h%02m%02s%02f'), '00010115');
#ok($tc->to_string('%mm%ss.%03ff %%m'), '1m1s.015f %m');
####
ok($tc->to_string(' '), ' ');
ok($tc->to_string('%H'), '1');
ok($tc->to_string('%M'), '2');
ok($tc->to_string('%S'), '3');
ok($tc->to_string('%f'), '15');
ok($tc->to_string('%r'), $tc->fps);
ok($tc->to_string('%T'), '01:02:03+15');
ok($tc->to_string('%02H'), '01');
ok($tc->to_string('%02HH'), '01H');
ok($tc->to_string('%H%%H'), '1%H');
######

#parse with frame_delimiter char
$tc = Time::Timecode->new('00:00:00+11', { frame_delimiter => '+' });
hmsf_ok($tc, 0, 0, 0, 11);
ok($tc->to_string, '00:00:00+11');

#invalid dropframe timecode ';' means dropframe
eval{ $tc = Time::Timecode->new('00:01:00;00') };
ok($@);

