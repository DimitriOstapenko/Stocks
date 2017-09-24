#!/usr/bin/perl

use Stocks::User;
use Stocks::Utils;
use Stocks::Portfolio;
use Data::Dumper;

my $USER = Stocks::User::get ( username => 'mlc');

my $tframe = 'mtd';

my $range = Stocks::Utils::getDateRange ($tframe);
my $totals =  $USER->getTotalPortfolioHist (sdate => $range->{sdate}, edate => $range->{edate}, short_date => 0);


print Dumper $totals;
