#!/usr/bin/perl

use Stocks::Portfolio;
use Data::Dumper;
use Smart::Comments;

my $portid = 38;
my $port = Stocks::Portfolio::get (id => $portid);

my $ttlcurval = $port->curvalue();
my $equity = $port->equity();
my $assets = $port->assets;

print $ttlcurval;
print Dumper $assets;
exit;

#my $pprgains = $port->getPprGains;

#print Dumper $pprgains;

#foreach my $sym (keys %$pprgains) {
# print  $sym ,':', int $pprgains->{$sym}, "\n";
#}

#my $ttl;
#map { $ttl += $_ } values %$pprgains;
#print $ttl;

my $symbol = 'RY:TSX';
my $tframe = 'lyr';

my $trades = $port->getTrades ( symbol => $symbol, tframe => $tframe);

#print Dumper $trades;

my ($date,$rgain,$ttlrgain,$ttlnumber);
foreach my $tr ( @$trades ) {
  ($date) = split (" ", $tr->date);
   $rgain = $tr->equity+$tr->cash;
   $ttlrgain += $rgain;
   $ttlnumber += $tr->number;
  print $tr->symbol.':'.$tr->exchange.'|'.$date.'|'.$tr->number.'|'.
	sprintf("%-8.2f",$tr->equity).'|'.
	sprintf("%-8.2f",$tr->cash).'|'.
	sprintf("%-8.2f",$rgain).'|'.$tr->descr."\n";
}

print 'Total R gain :'. sprintf("%-8.2f",$ttlrgain). "\n";
print 'Total number :'. $ttlnumber."\n";

