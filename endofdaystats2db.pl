#!/usr/bin/perl
#
# Stock portfolio project
# Get end of day quotes for all symbols in all portfolios
# and calculate current value of each stock;
# Then save the results into portfolio_history table
#
# Sum up all positions and save totals of equity and cash for each portfolio
# into daily_totals table
# convert all cash to base cash (CAD)
#
# Runs at the end of business day
#
# by Dmitri Ostapenko, d@perlnow.com, Jun 2009
#

use strict;
use Stocks::User;
use Stocks::Portfolio;
use Stocks::PortfolioHistory;
use Stocks::DailyTotals;
use Stocks::Quote;
use DateTime;
use Data::Dumper;
#use Smart::Comments;

print scalar(localtime()) , "... \n";

my $dt = DateTime->now(time_zone => 'local');
my $today = $dt->ymd;
my ($positions,$curval);
my $debug = 0;
 
print "*** Debug mode enabled - results won't be saved into BD \n" if $debug;
 
my $usdcad =  Stocks::Quote::get( symbol=> 'USDCAD=X', exchange => 'NYSE');
my $usdprice = $usdcad->{price} if ref $usdcad;

my $users = Stocks::User::getAll();

foreach my $usr ( @$users ) {

  my $ports = Stocks::Portfolio::getAll( username => $usr->{username}, showinactive => 1);
  foreach my $portid ( keys %$ports ) {
    my $port = Stocks::Portfolio::get ( id => $portid);
   
    print 'Portfolio ', $port->username, ' : ', $port->name, ' (',$port->opt_name,")\n";

    $curval = 0;
    foreach my $ass ( @{$port->assets} ) {
      my $quote = Stocks::Quote::get ( symbol => $ass->{symbol}, exchange => $ass->{exchange} );

#      if ($port->id == 55) {
#         print 'symbol :', $ass->{symbol}, " last price: ",  $quote->last, "\n";
#      }

      next if $quote->__errormsg();
      print $ass->{number}, ' ', $ass->{symbol}, "\n";
      my $porthist = Stocks::PortfolioHistory->new(  
  				 portid => $portid,
				 symbol => $ass->{symbol},
				 exchange => $ass->{exchange},
				 date   => $today,
				 acb    => $ass->{acb} || 0,
				 price  => $quote->last,
				 number => $ass->{number}
			       );
 
      $curval += $quote->last * $ass->{number}; 
      $porthist->save () unless $debug;
    }

# convert all to base currency (CDN)

    my $fx_rate = ($port->currency eq 'CAD') ? 1 : $port->fx_rate();
    print "equity: ", $curval, "\n" if $debug;
    print "cash: ", $port->cash(), "\n" if $debug;
    print "fx_rate: ",$fx_rate, "\n" if $debug;
    
    my $totals = Stocks::DailyTotals->new ( portid => $portid, 
   					    date => $today,
					    equity => $curval * $fx_rate,
					    cash => $port->cash * $fx_rate
					  );

    print '*** Total: equity: ', $curval, ' cash: ', $port->cash*$fx_rate, "  ***\n\n"; 
    $totals->save unless $debug;
					
  } # portfolios
} # users

# This is now done in separate script: reset_last_usdcad.pl
# Reset USDCAD_LAST in quote table to current fx
# Stocks::Quote::cache_usdcad();
