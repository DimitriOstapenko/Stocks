#!/usr/bin/perl
#
# Get symbol quote (US and Canada) from yahoo site using Finance::Quote
# You can use 'usa' or 'canada' for exchange 
# For canadian symbols use 
#  <symbol>.to: tsx
#  <symbol>.v: venture
#
# ./finquote.pl RY.TO yahoo 
# ./finquote.pl RY usa
# by D.O Sep 20 2007

use strict;
use Finance::Quote;
use Data::Dumper;

my $q = Finance::Quote->new;
my ($symbol, $exchange) = @ARGV;
chomp $exchange;
#$symbol = uc $symbol;
die "need symbol \n" unless $symbol;
die "need exchange \n" unless $exchange;

print 'symbol : "', $symbol, '" exchange : ', $exchange, "\n";

my %quote = $q->fetch( $exchange, $symbol);

my @sources = $q->sources;
print join"\n", @sources;

print join"\n", keys %quote;

$symbol =~ tr/^//d;

foreach my $key ( keys %quote ) {
  my $nkey = $key;
  $nkey =~ s/$symbol//;
  $nkey =~ s/^\W+//;     # get rid of whitespace and other noise (fileseparator 28)
  $nkey =~ s/\W+$//;

  $quote{$nkey} = $quote{$key};
  print "$nkey => $quote{$key}\n";
  delete $quote{key};
}

if ($quote{success}) {
   print "successful quote\n";
} else {
   print 'quote failed: ', $quote{errormsg}, "\n";
}  
