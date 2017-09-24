package Stocks::Startup;


# Apache::DBI is loaded before everything else - see apache config file

use version; our $VERSION = qv('1.0.0');
use strict;
use Carp;
use Data::Dumper;
use Smart::Comments;

### Loading Stocks Startup ...

use Stocks::Config;
use Stocks::DB;
use Stocks::Utils;
use Stocks::Transaction;
use Stocks::Quote;
use Stocks::Portfolio;
use Stocks::PortfolioHistory;
use Stocks::TransactionHistory;
use Stocks::DailyTotals;
use Stocks::User;
use List::Util qw[min max];

my $usdcad = Stocks::Quote::get( symbol=> $CONFIG->{indices}->{usdcad}{symbol}, 
				 exchange => $CONFIG->{indices}->{usdcad}{exchange}
				      );
$CONFIG->{USDCAD} = $usdcad->{price} if defined $usdcad;

my $eurcad = Stocks::Quote::get( symbol=> $CONFIG->{indices}->{eurcad}{symbol}, 
		 		 exchange => $CONFIG->{indices}->{eurcad}{exchange}
				      );
$CONFIG->{EURCAD} = $eurcad->{price} if defined $eurcad;

my $gold = Stocks::Quote::get( symbol=> $CONFIG->{indices}->{gold}{symbol}, 
		 	       exchange => $CONFIG->{indices}->{gold}{exchange}
				      );
$CONFIG->{GOLD} = $gold->{price} if defined $gold;

1;

__END__

=head1 Stocks::Startup 

Stocks::Startup -  load all frequently used modules and set up dynamic $CONFIG sections

=head1 VERSION

This documentation refers to FN::Startup version 1.0.0

=head1 SYNOPSIS

    use Stocks::Startup;

=head1 DESCRIPTION


This module loads all frequently used site-wide modules into memory under mod_perl.
It also sets up dynamic $CONFIG sections that require DB reading.

It should be loaded from startup.pl required in apache config. Use:

    PerlRequire     /.../startup.pl
