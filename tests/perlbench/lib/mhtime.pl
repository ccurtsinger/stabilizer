##---------------------------------------------------------------------------##
##  File:
##	$Id: mhtime.pl,v 2.10 2001/09/17 16:09:35 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##      Time related routines for mhonarc
##---------------------------------------------------------------------------##
##    Copyright (C) 1996-1999	Earl Hood, mhonarc@mhonarc.org
##
##    This program is free software; you can redistribute it and/or modify
##    it under the terms of the GNU General Public License as published by
##    the Free Software Foundation; either version 2 of the License, or
##    (at your option) any later version.
##
##    This program is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU General Public License for more details.
##
##    You should have received a copy of the GNU General Public License
##    along with this program; if not, write to the Free Software
##    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
##    02111-1307, USA
##---------------------------------------------------------------------------##

package mhonarc;

##---------------------------------------------------------------------------##
##      Date variables for date routines
##
my %Month2Num = (
    'jan', 0, 'feb', 1, 'mar', 2, 'apr', 3, 'may', 4, 'jun', 5, 'jul', 6,
    'aug', 7, 'sep', 8, 'oct', 9, 'nov', 10, 'dec', 11,
    'january', 0, 'february', 1, 'march', 2, 'april', 3,
    'may', 4, 'june', 5, 'july', 6, 'august', 7,
    'september', 8, 'october', 9, 'november', 10, 'december', 11,
);
my %WDay2Num = (
    'sun', 0, 'mon', 1, 'tue', 2, 'wed', 3, 'thu', 4, 'fri', 5, 'sat', 6,
    'sunday', 0, 'monday', 1, 'tuesday', 2, 'wednesday', 3, 'thursday', 4,
    'friday', 5, 'saturday', 6,
);

my @wdays = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
my @Wdays = ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
	     'Friday', 'Saturday');
my @mons   = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug',
	      'Sep', 'Oct', 'Nov', 'Dec');
my @Mons   = ('January', 'February', 'March', 'April', 'May', 'June',
	      'July', 'August', 'September', 'October', 'November',
	      'December');

## The following used in parse_date() regexes
my $p_weekdays = 'Mon|Tue|Wed|Thu|Fri|Sat|Sun';
my $p_Weekdays = 'Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday';
my $p_months   = 'Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec';
my $p_Months   = 'January|February|March|April|May|June|July|August'.
		 '|September|October|November|December';
my $p_hrminsec = '\d{1,2}:\d\d:\d\d';
my $p_hrmin    = '\d{1,2}:\d\d';
my $p_day      = '\d{1,2}';
my $p_year     = '\d\d\d\d|\d\d';

##---------------------------------------------------------------------------
##	Set weekday and month names.  This allows localization of
##	names.
##
sub set_date_names {
    my($in_wd, $in_Wd, $in_m, $in_M) = @_;

# CPU2006
return;

    @wdays = @$in_wd	if defined($in_wd) && scalar(@$in_wd);
    @Wdays = @$in_Wd	if defined($in_Wd) && scalar(@$in_Wd);
    @mons  = @$in_m 	if defined($in_m)  && scalar(@$in_m);
    @Mons  = @$in_M 	if defined($in_M)  && scalar(@$in_M);
}

##---------------------------------------------------------------------------
##	Get date in date(1)-like format.  $local flag is if local time
##	should be used.
##
sub getdate {
    &time2str('', time, $_[0]);
}

##---------------------------------------------------------------------------
##	Convert a calander time to a string.
##
sub time2str {
    my($fmt, $time, $local) = @_;
    my($date) = "";

# CPU2006 -- always use GMT
$local = 0;

    ## Get current date/time
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	    ($local ? localtime($time) : gmtime($time));

    ## If format string blank, use default format
    if ($fmt !~ /\S/) {
	$fmt  = '%a %b %d %H:%M:%S';
	$fmt .= ' GMT'  unless $local;
	$fmt .= ' %Y';
    }

# CPU2006
#    POSIXMODCHK: {
#	last  POSIXMODCHK  unless $POSIXstrftime;
#	eval { require POSIX; };
#	last  POSIXMODCHK  if ($@) || !defined(&POSIX::strftime);
#	return POSIX::strftime($fmt, $sec,$min,$hour,$mday,$mon,$year,
#				     $wday,$yday,$isdst);
#    }

    ## Get here, we have to do it ourselves.
    my($yearfull, $hour12);
    $yearfull = $year + 1900;
    $year     = $year % 100;
    $hour12   = $hour > 12 ? $hour-12 : $hour;

    ## Format output
    $fmt =~ s/\%c/\%a \%b \%d \%H:\%M:\%S \%Y/g;

    $fmt =~ s/\%a/$wdays[$wday]/g;
    $fmt =~ s/\%A/$Wdays[$wday]/g;
    $fmt =~ s/\%[bh]/$mons[$mon]/g;
    $fmt =~ s/\%B/$Mons[$mon]/g;

    $sec	= sprintf("%02d", $sec);
    $min	= sprintf("%02d", $min);
    $hour	= sprintf("%02d", $hour);
    $hour12	= sprintf("%02d", $hour12);
    $mday	= sprintf("%02d", $mday);
    $mon	= sprintf("%02d", $mon+1);
    $year	= sprintf("%02d", $year);
    $yearfull	= sprintf("%04d", $yearfull);
    $wday	= sprintf("%02d", $wday+1);
    $yday	= sprintf("%03d", $yday);

    $fmt =~ s/\%d/$mday/g;
    $fmt =~ s/\%H/$hour/g;
    $fmt =~ s/\%I/$hour12/g;
    $fmt =~ s/\%j/$yday/g;
    $fmt =~ s/\%m/$mon/g;
    $fmt =~ s/\%M/$min/g;
    $fmt =~ s/\%n/\n/g;
    $fmt =~ s/\%p/am/g if ($hour < 12);
    $fmt =~ s/\%p/pm/g if ($hour >= 12);
    $fmt =~ s/\%P/AM/g if ($hour < 12);
    $fmt =~ s/\%P/PM/g if ($hour >= 12);
    $fmt =~ s/\%S/$sec/g;
    $fmt =~ s/\%w/$wday/g;
    $fmt =~ s/\%y/$year/g; 
    $fmt =~ s/\%Y/$yearfull/g; 

    $fmt =~ s/\%\%/\%/g ; 

    $date = $fmt ;

    $date ;
}

##---------------------------------------------------------------------------
##	parse_date takes a string date specified like the output of
##	date(1) into its components.  Parsing a string for a date is
##	ugly since we have to watch out for differing formats.
##
##	The following date formats are looked for:
##
##	    Wdy DD Mon YY HH:MM:SS Zone
##	    DD Mon YY HH:MM:SS Zone
##	    Wdy Mon DD HH:MM:SS Zone YYYY
##	    Wdy Mon DD HH:MM:SS YYYY
##
##	The routine keys off of the day of time field "HH:MM:SS" and
##	scans realtive to its location.
##
##	If the parse fails, a null array is returned. Thus the routine
##	may be used as follows:
##
##          if ( (@x = &parse_date($date)) ) { Success }
##          else { Fail }
##
##	If success the array contents are as follows:
##
##	    (Weekday (0-6), Day of the month (1-31), Month (0-11),
##	     Year, Hour, Minutes, Seconds, Time Zone)
##
##	Contributer(s): Frank J. Manion <FJ_Manion@fccc.edu>
##
sub parse_date {
    my($date) = $_[0];
    my($wday, $mday, $mon, $yr, $time, $hr, $min, $sec, $zone);
    my(@array);
    my($start, $rest);

    # Try to find the date by focusing on the "\d\d:\d\d" field.
    # All parsing is then done relative to this location.
    #
    $date =~ s/^\s+//;  $time = "";  $rest = "";
    #	 Don't use $p_hrmin(sec) vars in split due to bug in perl 5.003.
    ($start, $time, $rest) = split(/(\b\d{1,2}:\d\d:\d\d)/o, $date, 2);
    ($start, $time, $rest) = split(/(\b\d{1,2}:\d\d)/o, $date, 2)
	    if !defined($time) or $time eq "";
    return ()
	unless defined($time) and $time ne "";

    ($hr, $min, $sec) = split(/:/, $time);
    $sec = 0  unless $sec;          # Sometimes seconds not defined

    # Strip $start of all but the last 4 tokens,
    # and stuff all tokens in $rest into @array
    #
    @array = split(' ', $start);
    $start = join(' ', ($#array-3 < 0) ? @array[0..$#array] :
					 @array[$#array-3..$#array]);
    @array = split(' ', $rest);
    $rest  = join(' ', ($#array  >= 1) ? @array[0..1] :
					 $array[0]);
    # Wdy DD Mon YY HH:MM:SS Zone
    if ( $start =~
	 /($p_weekdays),*\s+($p_day)\s+($p_months)\s+($p_year)$/io ) {

	($wday, $mday, $mon, $yr, $zone) = ($1, $2, $3, $4, $array[0]);

    # DD Mon YY HH:MM:SS Zone
    } elsif ( $start =~ /($p_day)\s+($p_months)\s+($p_year)$/io ) {
	($mday, $mon, $yr, $zone) = ($1, $2, $3, $array[0]);

    # Wdy Mon DD HH:MM:SS Zone YYYY
    # Wdy Mon DD HH:MM:SS YYYY
    } elsif ( $start =~ /($p_weekdays),?\s+($p_months)\s+($p_day)$/io ) {
	($wday, $mon, $mday) = ($1, $2, $3);
	if ( $rest =~ /^(\S+)\s+($p_year)/o ) {	# Zone YYYY
	    ($zone, $yr) = ($1, $2);
	} elsif ( $rest =~ /^($p_year)/o ) {	# YYYY
	    ($yr) = ($1);
	} else {				# zilch, use current year
	    warn "Warning: No year in date ($date), using current\n";
    # CPU2006 -- use only 1 year
	    #$yr = (localtime(time))[5];
	    $yr = 2004;
	}

    # Weekday Month DD YYYY HH:MM Zone
    } elsif ( $start =~
	      /($p_Weekdays),?\s+($p_Months)\s+($p_day),?\s+($p_year)$/ ) {
	($wday, $mon, $mday, $yr, $zone) = ($1, $2, $3, $4, $array[0]);

    # All else fails!
    } else {
	return ();
    }

    # Modify month and weekday for lookup
    $mon  = $Month2Num{lc $mon}  if defined($mon);
    $wday = $WDay2Num{lc $wday}  if defined($wday);

    ($wday, $mday, $mon, $yr, $hr, $min, $sec, $zone);
}

##---------------------------------------------------------------------------
##	Routine to convert time in seconds to a month, day, and year
##	format.  The format can be "mmddyy", "yymmdd", "ddmmyy".  The
##	year can be specifed as "yyyy" if a 4 digit year is needed.
##
sub time2mmddyy {
    my($time, $fmt) = ($_[0], $_[1]);
    my($day,$mon,$year,$ylen,$tmp);
    if ($time) {
# CPU2006 -- use GMT
	#($day,$mon,$year) = (localtime($time))[3,4,5];
	($day,$mon,$year) = (gmtime($time))[3,4,5];
	$year += 1900;

	## Compute length for year field
	$ylen = $fmt =~ s/y/y/g;
	substr($year, 0, 4 - $ylen) = '';

	## Create string
	if ($fmt =~ /ddmmyy/i) {	# DDMMYY
	    $tmp = sprintf("%02d/%02d/%0${ylen}d", $day, $mon+1, $year);

	} elsif ($fmt =~ /yymmdd/i) {	# YYMMDD
	    $tmp = sprintf("%0${ylen}d/%02d/%02d", $year, $mon+1, $day);

	} else {			# MMDDYY
	    $tmp = sprintf("%02d/%02d/%0${ylen}d", $mon+1, $day, $year);
	}

    } else {
	$tmp = "--/--/--";
    }
}

##---------------------------------------------------------------------------
##	zone_offset_to_secs translates a [+-]HHMM zone offset to
##	seconds.
##
sub zone_offset_to_secs {
    my($off) = shift;
    my($sign, $min);

    ## Check if just an hour specification
    if (length($off) < 4) {
	return $off * 3600;
    }
    ## Check for sign
    if ($off =~ s/-//) {
	$sign = -1;
    } else {
	$sign = 1;  s/\+//;
    }
    ## Extract minutes
    $min = substr($off, -2, 2);
    substr($off, -2, 2) = "";	# Just leave hour in $off

    ## Translate to seconds
    $sign * (($off * 3600) + ($min * 60));
}

##---------------------------------------------------------------------------##
1;
