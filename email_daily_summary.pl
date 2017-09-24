#!/usr/bin/perl
#
# Produce summary table across all portfolios for each user and send it to user if she's subscribed to this service
# 
#
# by D.O d@perlnow.com

use Stocks::User;
use Stocks::Portfolio;
use Stocks::Quote;
use Stocks::Utils;
use Mail::Send;
#use Smart::Comments;
use DateTime;
use Carp;

use strict;

my $usdcad = Stocks::Utils::get_usdcad || 1;
my $eurcad = Stocks::Utils::get_eurcad || 1;
my $gold = Stocks::Utils::get_gold;
my $dt = DateTime->now(time_zone => 'local');
my $today = $dt->ymd;

my $users = Stocks::User::getAll();
my ($email_subs,$grandtotal,$daygain,$daydep);

foreach my $usr ( @$users ) {
   my $user = Stocks::User::get (id => $usr->{id});
   $email_subs = $user->email_subs;
   do_user ( $user ) if grep /^port$/, @$email_subs;
}

# Send email to this user
# ARG: user obj
# RET: none

sub do_user {
my $user = shift;
my ($port,$ttls,$curval,$cash);

print 'doing ', $user->username, "\n";

my $ports = $user->getPortfolios;

my $msg = "<pre>\n\n";
#  = '<pre>User: '. $user->username. "\n\n";
$msg .= sprintf  "%-10s | %-8s | %-8s | %-8s | %-8s | \n", 'Portfolio', 'Equity', 'Cash', 'Total', 'Day G/L';
$msg .= sprintf  "%s \n", '='x56;

foreach my $id (keys %$ports ) {
   $port = Stocks::Portfolio::get ( id => $id );
   print $port->name, ':', $port->cashin, "\n";

   next unless abs($port->cashin) > 10;
   $ttls = port_totals ( $port );

   $cash += $ttls->{cash};
   $curval += $ttls->{curval};
   $daygain += $ttls->{daygain};
   $daydep += $ttls->{daydep};

   $msg .= sprintf ("%-10s | ", substr($port->name,0,10)); 
   $msg .= sprintf ("\$%-8i| ", $ttls->{curval} );
   $msg .= sprintf ("\$%-8i| ", $ttls->{cash});
   $msg .= sprintf ("\$%-8i| ", $ttls->{curval} + $ttls->{cash});
   $msg .= sprintf ("\$%-8i| \n", $ttls->{daygain});
}   

$grandtotal = $curval + $cash;

$msg .= sprintf "%s \n", '='x56;
$msg .= sprintf "%-10s   \$%-9i \$%-9i \$%-9i \$%-9i \n", ' ', $curval, $cash, $curval + $cash, $daygain;
$msg .= sprintf "\nTotal deposits today: $daydep" if $daydep;
$msg .= sprintf "\n** All values in \$CDN \nUSD/CAD : $usdcad \nEUR/CAD : $eurcad \nGOLD: $gold\n";
$msg .= sprintf "\nDeposits must be added during trading day before 4:30pm";
$msg .= sprintf "\nto be reflected in this statement.";
$msg .= sprintf "\n\nOnly portfolios with cash balance are included </pre>";

send_mail ($user,$msg);

} # do_user

# Send email to user
# ARG: user obj
# RET: none

sub send_mail {
my ($user,$msg) = @_;

print 'sending email to '. $user->email1 . "\n";
my $em = Mail::Send->new(Subject => "Daily Summary: ". sprintf("\$%-8.0f", $grandtotal). ' (' . sprintf ("\$%+6.0f", $daygain). ')',
			 To => $user->email1
		 	);

$em->set('From' , 'stocks@perlnow.com');
$em->set('Content-type', 'text/html');  # !!!!!

my $fh = $em->open;  
printf $fh $msg;
$fh->close;

} # send_mail

# Get portfolio totals from daily_totals table as well as change in value from last trading day
# ARG: port obj
# RET: hashref

sub port_totals {
    my $port = shift;
    my ($cash,$equity,$pdaycash,$pdayequity,$date,$fx);

    $fx = 1;
    $fx = $port->fx_rate() unless ($port->currency eq 'CAD');
   
# get totals in base currency from daily_totals table 
    my $last = $port->getLastTotals();
    my $prev = $port->getPrevTotals();
    my $daydep = $port->getDayTotalDep() * $fx;
  
### Portfolio:  $port->name 
### Last : $last
### prev : $prev
### daydep : $daydep
    
#    return unless abs($port->cashin()) > 1;

    if ($last) {
        $cash = $last->cash;
        $equity = $last->equity;
	$date = $last->date;
    }
    if ($prev) {
        $pdaycash = $prev->cash;
        $pdayequity = $prev->equity;
    }

#   print "date: $date; cash : $cash ; equity: $equity ; change: ",($cash+$equity) - ($pdaycash+$pdayequity), "\n";

# No data for today in daily_totals table - do nothing
    do{croak "there's no data for today in daily_totals table!"; return; } unless $date eq $today;

    return {('curval' => $equity, 
    	     'cash' => $cash, 
    	     'daydep' => $daydep, 
	     'daygain' => ($cash+$equity) - ($pdaycash+$pdayequity)
	   )};
}

