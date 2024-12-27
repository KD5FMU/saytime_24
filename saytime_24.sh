#!/usr/bin/perl

# Copyright 2013, 2019 - saytime.pl - D. Crompton, WA3DSP
#
# Perl program to emulate and replace the app_rpt time of day 
# function call. This allows for easy changes and also volume and 
# tempo modifications.
#
# Call this program from a cron job and/or rpt.conf when you want to 
# hear the time on your local node in 24-hour format.
#
# Example Cron job to say the time on the hour every hour:
# 00 0-23 * * * cd /etc/asterisk/wa3dsp; perl saytime.pl [<wxid>] <node> > /dev/null

use strict;
use warnings;

select (STDOUT);
$| = 1;
select (STDERR);
$| = 1;

my $outdir = "/tmp";
my $base = "/var/lib/asterisk/sounds";
my ($FNAME, $error, $day, $hour, $min, $mynode, $wx, $wxid);
my ($sec, $wday, $mon, $year_1900, $isdst, $min1, $min10, $localwxtemp10, $localwxtemp1);
my $filename, my $Silent=0;

my $num_args = $#ARGV + 1;

if ($num_args == 1) {
    $mynode=$ARGV[0];
    $wx = "NO";
    $error=0;
} elsif ($num_args == 2) {
    $wxid = $ARGV[0]; 
    $wx = "YES";
    $mynode=$ARGV[1];
    $error=0;
} elsif ($num_args == 3) {
    $wxid = $ARGV[0];
    $wx = "YES";
    $mynode=$ARGV[1];
    $Silent=$ARGV[2];
    $error = $Silent < 0 || $Silent > 2 ? 1 : 0;
} else {
    $error=1;
}

if ($error == 1) {
  print "\nUsage: saytime.pl [<locationid>] nodenumber [1=save time and wx, 2=save wx - both no voice]\n\n";
  exit;
}

my $localwxtemp="";

if ($wx eq "YES" && -f "/usr/local/sbin/weather.sh") {
    system("/usr/local/sbin/weather.sh " . $wxid);

    if (-f "$outdir/temperature") { 
        open(my $fh, '<', "$outdir/temperature") or die "cannot open file";
        $localwxtemp = <$fh>;
        close($fh);
    }
}

$filename = '/etc/asterisk/local/saytime_header';
if ( <$filename.*> ) {
    system("/usr/sbin/asterisk -rx \"rpt localplay $mynode /etc/asterisk/local/saytime_header\"");
}

($sec,$min,$hour,$day,$mon,$year_1900,$wday,$yday,$isdst) = localtime;

if ($Silent != "2") {
    my $greet = $hour < 12 ? "Good Morning" : ($hour < 18 ? "Good Afternoon" : "Good Evening");
    $FNAME = $base . "/$greet.gsm " . $base . "/the-time-is.gsm " . $base . "/digits/$hour.gsm ";

    if ($min != 0) {
        if ($min < 10) {
            $FNAME .= $base . "/digits/oh.gsm " . $base . "/digits/$min.gsm ";
        } elsif ($min < 20) {
            $FNAME .= $base . "/digits/$min.gsm ";
        } else {
            $min10 = int($min / 10) * 10;
            $min1 = $min % 10;
            $FNAME .= $base . "/digits/$min10.gsm " . ($min1 > 0 ? $base . "/digits/$min1.gsm " : "");
        }
    }
}

if ($wx eq "YES" && $localwxtemp ne "") {
    $FNAME .= handle_weather($localwxtemp, $base, $outdir);
}

sub handle_weather {
    my ($temp, $base, $outdir) = @_;
    my $weather_string = $base . "/silence/1.gsm ";

    if (-e "$outdir/condition.gsm") {
        $weather_string .= $base . "/weather.gsm " . $base . "/conditions.gsm " . "$outdir/condition.gsm ";
    }
    if ($temp ne "" ) {
        $weather_string .= $base . "/wx/temperature.gsm ";
        if ($temp < -1) {
            $weather_string .= $base . "/digits/minus.gsm ";
            $temp = abs($temp);
        }
        if ($temp >= 100) {
            $weather_string .= $base . "/digits/1.gsm " . $base . "/digits/hundred.gsm ";
            $temp -= 100;
        }
        if ($temp < 20) {
            $weather_string .= $base . "/digits/$temp.gsm ";
        } else {
            my $tens = int($temp / 10) * 10;
            my $ones = $temp % 10;
            $weather_string .= $base . "/digits/$tens.gsm " . ($ones > 0 ? $base . "/digits/$ones.gsm " : "");
        }
        $weather_string .= $base . "/degrees.gsm ";
    }
    return $weather_string;
}

system("cat $FNAME > $outdir/current-time.gsm");

if ($Silent == "0") {
    system("/usr/sbin/asterisk -rx \"rpt localplay $mynode $outdir/current-time\"");
} elsif ($Silent == "1") {
    print "\nSaved time and weather sound file to $outdir/current-time.gsm\n\n";
} elsif ($Silent == "2") {
    print "\nSaved weather sound file to $outdir/current-time.gsm\n\n";
}

# end of saytime.pl
