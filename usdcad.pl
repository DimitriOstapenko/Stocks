#!/usr/bin/perl

use strict;
use Finance::Quote;
use Data::Dumper;

my $q = Finance::Quote->new;

my $exchange='nyse';
my $symbol='USDCAD=X';

my %quote = $q->fetch( $exchange, $symbol);
print Dumper %quote;

my $conversion_rate = $q->currency("USD","CAD");

print $conversion_rate ;
