use Test;
use Time::Timecode;

require 't/util.pl';

BEGIN { plan tests => 47 }

# Addition
$tc = Time::Timecode->new(29) + Time::Timecode->new(1);
hmsf_ok($tc, 0, 0, 1, 0);

# results get their settings from the LHS
$tc = Time::Timecode->new(1800, { dropframe => 1 }) + Time::Timecode->new(1);
ok($tc->is_dropframe);
hmsf_ok($tc, 0, 1, 0, 3);

$tc = Time::Timecode->new(24, { fps => 25 }) + Time::Timecode->new(1);
ok($tc->fps, 25);
hmsf_ok($tc, 0, 0, 1, 0);

# Subtraction
$tc = '12:00:00:00' - Time::Timecode->new(1, 0, 0, 1);
hmsf_ok($tc, 10, 59, 59, 29);

$tc =  Time::Timecode->new(1, 0, 10) - 1;
hmsf_ok($tc, 1, 0, 9, 29);

eval { $tc = Time::Timecode->new(1) - 100 };
ok($@);

eval { $tc = Time::Timecode->new(1, { fps => 'xxx' }) };
ok($@);

# Multiplication
$tc =  Time::Timecode->new(0, 1, 0) * Time::Timecode->new(0, 0, 5, 25, { dropframe => 1 });
ok(!$tc->is_dropframe);
hmsf_ok($tc, 2, 55, 0, 0);

# Division
$tc =  31 / Time::Timecode->new(16);
hmsf_ok($tc, 0, 0, 0, 1);

$tc =  Time::Timecode->new(1800) / 3600;
hmsf_ok($tc, 0, 0, 0, 0);

# Comparision
my $tc1 = Time::Timecode->new(0);
my $tc2 = Time::Timecode->new(1800);
ok($tc1 < $tc2);
ok($tc1 <= $tc1);
ok(!($tc2 < $tc1));
ok($tc1 <=> $tc2, -1);
ok($tc1 <=> $tc1, 0);
ok($tc2 <=> $tc1, 1);
ok($tc1 cmp $tc2, -1);
ok($tc1 cmp $tc1, 0);
ok($tc2 cmp $tc1, 1);

# Etc...
# hours > 99
eval { $tc =  Time::Timecode->new(1) * 2000000000000000000 };
ok($@);
