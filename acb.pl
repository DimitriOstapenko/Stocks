#!/usr/bin/perl

use Stocks::Portfolio;

my $portid = 38;
my $port = Stocks::Portfolio::get ( id => $portid);
 
foreach my $ass ( @{$port->assets} ) {

   next unless $ass->{symbol} eq 'WFC';
   print 'acb: ', $ass->{acb}, "\n";

}
