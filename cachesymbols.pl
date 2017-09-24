#!/usr/bin/perl
#
# Stock portfolio project
# Put quotes for unique symbols in all portfolios into quote table in DB
# Will run every few minutes from cron during business hours
#
# by Dmitri Ostapenko, d@perlnow.com, Nov 2008
#

use Stocks::Config qw($CONFIG);
use Stocks::Portfolio;
use Stocks::Quote;
use Stocks::DB;
use Data::Dumper;
use DateTime;

use strict;

print scalar(localtime()) , "... \n";

# Get symbols from all the portfolios:
   
   my %symbols = %{Stocks::Transaction::get_active_symbols()};

   print 'symbols: ', join':', keys %symbols, "\n";
   
# Add Indices

   my $ind = $CONFIG->{indices};
   my %indices = (
     tsx => Stocks::Quote::get( symbol=> $ind->{tsx}{symbol}, exchange => $ind->{tsx}{exchange}),
     dow => Stocks::Quote::get( symbol=> $ind->{dow}{symbol}, exchange => $ind->{dow}{exchange}),
     nasd => Stocks::Quote::get( symbol=> $ind->{nasd}{symbol}, exchange => $ind->{nasd}{exchange}),
     usdcad => Stocks::Quote::get( symbol=> $ind->{usdcad}{symbol}, exchange => $ind->{usdcad}{exchange}),
     crude => Stocks::Quote::get( symbol=> $ind->{crude}{symbol}, exchange => $ind->{crude}{exchange}),
     ngas => Stocks::Quote::get( symbol=> $ind->{ngas}{symbol}, exchange => $ind->{ngas}{exchange}),
     gold => Stocks::Quote::get( symbol=> $ind->{gold}{symbol}, exchange => $ind->{gold}{exchange}),
   );


### Gold quote broken! manual reset here:

   $indices{gold}->price(1160);

   %symbols = (%symbols,%indices);

   my $i = 1;
   while( my ($key,$val) = each %symbols ) {
# Use cached quotes if they have not expired yet:
#      print $key, "\n";
      my $q = Stocks::Quote::get( symbol => $val->{symbol}, exchange => $val->{exchange});
      print $i++,':',$q->symbol,':',$q->price,':',$q->timestamp, "\n";
   }
  
# As this runs during business hours, let's clean out old quotes (older than 4 hrs) during business hours:
 
   my $del_rows = Stocks::Quote::delete_expired();
   print 'deleted ', $del_rows, " expired quotes \n";

