#!/usr/bin/perl

use Stocks::Portfolio;
use Smart::Comments;


my $p = Stocks::Portfolio::get (id=>1);

my $dep = $p->getDeposits ( tframe => 'lqtd');

print $dep;





