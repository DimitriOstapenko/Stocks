# Common methods used throughout Stocks classes
#

package Stocks::Utils;

$VERSION = 1.00;
use strict;
use DateTime;
use Carp;
use Date::Calc qw(Monday_of_Week Week_of_Year);
use Time::Local;
use Regexp::Common qw/list/;
use Stocks::DB;
use Stocks::Config qw($CONFIG);
use Smart::Comments;

#use Stocks::Quote;         #     !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
use feature 'switch';
use feature 'say';

my $dtnow = undef;
$dtnow = DateTime->now(time_zone => 'local');

sub today {
  return $dtnow->ymd;
}

sub thisyr {
  return $dtnow->year;
}

sub lastyr {

  return $dtnow->year - 1 ;
}

sub thismon {
  return $dtnow->month;  # 1..12
}

sub lastmon {
  return $dtnow->subtract(months => 1)->month;
}

sub thisday {
  return $dtnow->day_of_month;
}

sub thisqtr {
  return $dtnow->quarter;
}

sub lastqtr {
  my $qtr = thisqtr();

  return $qtr > 1 ? $qtr - 1 : 4;

}

# Get usd to cad conversion rate from DB
# ARG: none
# RET: scalar

sub get_usdcad {
  return $CONFIG->{USDCAD} if defined $CONFIG->{USDCAD};

  my $ind = $CONFIG->{indices};
  my $usdcad = Stocks::Quote::get( symbol=> $ind->{usdcad}{symbol}, exchange => $ind->{usdcad}{exchange});

  return $usdcad->{price} if ref $usdcad and $usdcad->{price};
  return 1
}

# Get eur to cad conversion rate from DB
# ARG: none
# RET: scalar

sub get_eurcad {
  return $CONFIG->{EURCAD} if defined $CONFIG->{EURCAD};

  my $ind = $CONFIG->{indices};
  my $eurcad = Stocks::Quote::get( symbol=> $ind->{eurcad}{symbol}, exchange => $ind->{eurcad}{exchange});

  return $eurcad->{price} if ref $eurcad and $eurcad->{price};
  return 1
}

# Get gold price/oz from DB
# ARG: none
# RET: scalar

sub get_gold {
  return $CONFIG->{GOLD} if defined $CONFIG->{GOLD};

  my $ind = $CONFIG->{indices};
  my $gold = Stocks::Quote::get( symbol=> $ind->{gold}{symbol}, exchange => $ind->{gold}{exchange});

  return $gold->{price} if ref $gold and $gold->{price};
  return 1
}

# Get gold price/gram
# ARG: none
# RET: scalar

sub get_gold_gr {
  return $CONFIG->{GOLD}/31.1035 if defined $CONFIG->{GOLD};

  my $ind = $CONFIG->{indices};
  my $gold = Stocks::Quote::get( symbol=> $ind->{gold}{symbol}, exchange => $ind->{gold}{exchange});

  return $gold->{price}/31.1035 if ref $gold and $gold->{price};
  return 1
}


# get exchange rate for this symbol/portfolio
# ARG: portcurrency, symexchange
# RET: exchange rate for this symbol/portfolio

sub getFX {
    my %arg = @_;
    my $pcur = $arg{portcurrency};
    my $symex = $arg{symexchange};
    my $usdcad = get_usdcad();
    my $eurcad = get_eurcad();

    croak "'portcurrency' is required" unless $pcur;
    croak "'symexchange' is required" unless $symex;

#    port   stock
#    USD    TSX      * 1/usdcad
#    USD    !TSX     1
#    CDN    TSX      1
#    CDN    !TSX     * usdcad

if ($pcur eq 'USD') {
   if ($symex eq 'TSX') {
      return 1/$usdcad
   } else {
      return 1
   }
} elsif ($pcur eq 'CAD') {
   if ($symex eq 'TSX') {
      return 1
   } else {
      return $usdcad
   }
} elsif ($pcur eq 'EUR') {
   if ($symex eq 'TSX') {
      return 1/$eurcad
   } else {
      return 1
   }     
}

} # getFX

# Alias to getFX
sub getFx {
  my %arg = @_;
  
  return getFX(%arg); 
}

# Get usd to cad conversion rate from DB
# ARG: none
# RET: scalar

sub get_usdcad_last {
  my $ind = $CONFIG->{indices};
  my $usdcad_last = Stocks::Quote::get( symbol=> $ind->{usdcad_last}{symbol}, exchange => $ind->{usdcad_last}{exchange});

  return $usdcad_last->{price} if ref $usdcad_last;
}

# Get eur to cad conversion rate from DB
# ARG: none
# RET: scalar

sub get_eurcad_last {
  my $ind = $CONFIG->{indices};
  my $eurcad_last = Stocks::Quote::get( symbol=> $ind->{eurcad_last}{symbol}, exchange => $ind->{eurcad_last}{exchange});

  return $eurcad_last->{price} if ref $eurcad_last;
}


# Get CAD change in cents from yesterday's close
# ARG: none
# RET: change in cents

sub get_cadchange {
  my $usdcad = get_usdcad();
  my $usdcad_last = get_usdcad_last();

  return unless $usdcad && $usdcad_last;

  return (1/$usdcad - 1/$usdcad_last)*100
}

# Calc first day of the timeframe passed
# ARG: timeframe : 'td', 'wktd', 'mtd', 'lmo', 'lmtd', 'qtd', 'lqtr', 'lqtd', 'ytd', 'lyr', 'lytd', 'lyr-1', 'all' 
# RET: hashref sdate, edate 

sub getDateRange {
my $timeframe = shift;

my @QtrMon = (0,1,4,7,10);
my ($d,$m,$y) = ($dtnow->day, $dtnow->month, $dtnow->year);
my ($sdate,$edate);

given ($timeframe ) {
   when ('all')    { $sdate = '1969-01-01' }
   when ('td')     { $sdate = $dtnow->ymd }
   when ('wktd')   { my ($yr,$mon,$firstdayofthiswk) = Monday_of_Week(Week_of_Year($y,$m,$d));
                     $sdate = $yr.'-'.$mon.'-'.$firstdayofthiswk; 
	 	   }
   when ('mtd')    { $sdate = $y.'-'.$m.'-1'; }
   when (['lmo',
   	 'lmtd'])  { $sdate = $m>1 ? $y.'-'.($m-1).'-1': ($y-1).'-12-1'; 
	 	     $edate = "$y-$m-01" if $timeframe eq 'lmo';
		   }
   when ('qtd')    { $sdate = $y.'-'.$QtrMon[$dtnow->quarter].'-1'; }
   when (['lqtr', 
         'lqtd'])  { my $mon = $QtrMon[$dtnow->quarter-1];
	                $sdate = $mon ? "$y-$mon-01" : ($y-1).'-10-01';
  			$edate = $y.'-'.$QtrMon[$dtnow->quarter].'-1' if $timeframe eq 'lqtr';
		   }
   when ('ytd')    { $sdate = $y.'-01-01'; }
   when ('lyr')    { $sdate = ($y-1).'-01-01'; $edate = ($y-1).'-12-31'; }
   when ('lytd')   { $sdate = ($y-1).'-01-01' }
   when ('lyr-1')  { $sdate = ($y-2).'-01-01'; $edate = ($y-2).'-12-31'; }

   default { return }
}

   return {(sdate => $sdate, edate => $edate)}

} #getDateRange

# Is today Mon-Fri?
# ARG: none
# RET: bool

sub monToFri {

my ($sec, $min, $hr, $day, $month, $year, $weekday, $dayofyr, $junk_yuk) = localtime(time);
my @tf = localtime(time());

return 1 if $tf[6] > 0 && $tf[6] < 6;
}

# Take datetime '2008-10-12 00:00:00'
# and make unixtime out of it
#
sub toUnixTS{
 my $ts = shift;

 croak "timestamp is required" unless $ts;

 $ts =~ tr/-:T/ /;
 my @t = split(' ',$ts);
 $t[1]--;
 
# provide missing time fields if necessary:
 foreach my $tm (3..5) {
   $t[$tm] = 0 unless $t[$tm];
 }

 my $unix_ts = eval{timelocal(reverse @t)};

 return $unix_ts
}

sub commify {
local $_  = int shift;
1 while s/^([-+]?\d+)(\d{3})/$1,$2/;
return $_;
}

# Get Full/abbrev month name
# ARG: numon : numeric month starting with 1 for Jan
#      abbrev : 0|1
# RET: string

sub getMonthName {
  my %arg = @_;
  my $mon = $arg{numon};

  croak ("numon parameter is required") unless $mon;

  my @month = qw(January February March April May June July August September October November December);
  
  return unless $mon and $mon > 0 and $mon < 13;
  my $monstr = $month[$mon-1];
  return $arg{abbrev} ? substr($monstr, 0, 3).'.' : $monstr;
}

# Get full names of the timeframes
# ARG: none 
# RET: hashref

sub getTimeFrameNames {
use Tie::Hash::Indexed;
tie my %timeframe, 'Tie::Hash::Indexed';

%timeframe = (
       'td'   => 'Today',
       'wktd' => 'This Week',
       'mtd'  => 'This Month',
       'lmo'  => 'Last Month',
       'lmtd' => 'Last Month To Date',
       'qtd'  => 'This Quarter',
       'lqtr' => 'Last Quarter',
       'lqtd' => 'Last Quarter To Date',
       'ytd'  => 'Year To Date',
       'lyr'  => 'Last Year',
       'lytd' => 'Last Year To Date',
       'lyr-1'=> 'Year Before Last',
       'all'  => 'All Time'
       );

return %timeframe
}

# Convert perl array to Pg array
# ARG: array
# RET: string

sub array_to_pgarray {
    my @array = @_;
    
    return '{}' unless @array;

    my $str = '{'.(join(',', @array)).'}';
    
    return $str
}

# Convert Pg array string to perl array
# ARG: str
# RET: arrayref

sub pgarray_to_array {
   my $str = shift;   

   return unless $str;
   croak "Postgres array string required" unless $str =~ /\{$RE{list}{-pat=>'\"?\s*\w*\s*\"?'}{-sep=>','}\}/;

   $str =~ tr/{}//d;
   my @subs = split (',',$str);
  
   return \@subs
}

# Get exchanges from corresponding postgres data type
# ARG: none
# RET: arrayref
sub get_exchanges {

  my $rows = Stocks::DB::select ( qry => 'SELECT enum_range(NULL::exchangetype)', limit => 1,);
  my $exchanges = Stocks::Utils::pgarray_to_array ($rows->{enum_range});

  pop @$exchanges if @$exchanges;  # get rid of "" for last value
  return $exchanges
}

# Trim lead trail space from string
sub trim {
	my $proto = $_[0];

        if ( ref $proto ) {
	   $$proto =~ s/^\s+//;
	   $$proto =~ s/\s+$//;
	} else {
	   $proto =~ s/^\s+//;
	   $proto =~ s/\s+$//;
	}
	
	return $proto;
}


1;

__END__
