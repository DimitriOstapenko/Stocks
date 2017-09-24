#!/usr/bin/perl

use DateTime;
use Stocks::Portfolio;
use Stocks::Transaction;
use Mail::Send;
use strict;
use Smart::Comments;

my ($date,$time,$port);
my $dtnow = DateTime->now(time_zone => 'local');

my $fh;
my $username = 'mlc';
my $ports = Stocks::Portfolio::getAll ( username => $username );
my ($gain,$ttlgain);

my $em = Mail::Send->new(Subject => "Today's Trades", To => 'dosta@me.com' );
$em->set('From' , 'stocks@perlnow.com');

foreach my $id (keys %$ports ) {
   $port = Stocks::Portfolio::get ( id => $id ); 
   my $tr = $port->getAllTodayTrades ();
   next unless ref $tr && $tr->[0]->{number};
 
   $fh = fh_open ($em) unless $fh;
   
   foreach my $tr ( @$tr ) {
     ($date,$time) = split (' ', $tr->{date});
     if ($tr->{number} > 0 ) {
         printf $fh " %s : %s : %s : %s %i %s @ \$%-5.2f for a total of %i shares; new avg price: \$%-8.4f \n", 
  	        $time, $port->username, $port->name, 'bought', abs($tr->{number}), $tr->{symbol},
	        $tr->{price}, $tr->{ttlnumber}, $tr->{avgprice};
     } else {
         $gain = $tr->{equity} + $tr->{cash};
	 $ttlgain += $gain;
         printf $fh " %s : %s : %s : %s %i %s @ \$%-5.2f for a total of %i shares; P/L: \$%-8.2f \n", 
  	        $time, $port->username, $port->name, 'sold', abs($tr->{number}), $tr->{symbol},
	        $tr->{price}, $tr->{ttlnumber}, $gain;
     }
   } # trs
} # ports

printf $fh "\n\n %s : \$%-5.2f \n", ' Total Realized Gain : ', $ttlgain;

#print $fh $msg;
$fh->close if $fh;

sub fh_open {

$fh = $em->open;  # $fh = $msg->open('sendmail');
printf $fh "List of trades for %s \n\n", $dtnow->ymd;

return $fh;
}

