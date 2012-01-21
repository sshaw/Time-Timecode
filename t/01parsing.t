use Test;
use Time::Timecode;
use TestHelper;

BEGIN { plan tests => 47 }

# Parse non-dropframe
my $tc = Time::Timecode->new('01:02:03:04');
hmsf_ok($tc, 1, 2, 3, 4);
ok(!$tc->is_dropframe);
ok($tc->to_string, '01:02:03:04');

# Parse dropframe
$tc = Time::Timecode->new('00:01:00.02');
hmsf_ok($tc, 0, 1, 0, 2);
ok($tc->is_dropframe);
ok($tc->to_string, '00:01:00.02');
$tc = Time::Timecode->new('10:00:00;22');
hmsf_ok($tc, 10, 0, 0, 22);
ok($tc->is_dropframe);

# Normally a dropframe frame delimiter would make the timecode dropframe 
$tc = Time::Timecode->new('00:01:00.02', { dropframe => 0 });
ok(!$tc->is_dropframe);
ok($tc->total_frames, 1802);

# Parse dropframe and recreate with delimiter char
$tc = Time::Timecode->new('00:01:00;02', { delimiter => ',' });
hmsf_ok($tc, 0, 1, 0, 2);
# Should still have dropframe delimiter
ok($tc->to_string, '00,01,00;02');

# Parse with delimiter char
$tc = Time::Timecode->new('00,22,19;00', { delimiter => ','});
hmsf_ok($tc, 0, 22, 19, 0);
# Should still have dropframe delimiter
ok($tc->to_string, '00,22,19;00');

# Parse and recreate with frame_delimiter char
$tc = Time::Timecode->new('01:02:03:15', { fps => 30, frame_delimiter => '+' });
ok($tc->to_string(' '), ' ');
ok($tc->to_string('%H'), '1');
ok($tc->to_string('%M'), '2');
ok($tc->to_string('%S'), '3');
ok($tc->to_string('%f'), '15');
ok($tc->to_string('%i'), $tc->total_frames);
ok($tc->to_string('%r'), $tc->fps);
ok($tc->to_string('%T'), '01:02:03+15');
ok($tc->to_string('%02H'), '01');
ok($tc->to_string('%02H:%02M:%02S;%02f @ %rfps'), '01:02:03;15 @ 30fps');
ok($tc->to_string('%%%HH%%H'), '%1H%H');
######

#parse with frame_delimiter char
$tc = Time::Timecode->new('00:00:00+11', { frame_delimiter => '+' });
hmsf_ok($tc, 0, 0, 0, 11);
ok($tc->to_string, '00:00:00+11');

$Time::Timecode::DEFAULT_TO_STRING_FORMAT = '->%02S<-';
$tc = Time::Timecode->new(2, 1, 0);
ok("$tc", '->00<-');

#invalid dropframe timecode ';' means dropframe
eval{ $tc = Time::Timecode->new('00:01:00;00') };
ok($@);



