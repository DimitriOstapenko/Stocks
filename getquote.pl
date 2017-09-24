#!/usr/bin/perl
#
# get 2 parameters from jquery call (addTransaction1.mas) :
#  symbol : stock symbol 
#  ecxh   : exchange where this equity is traded: TSX | other (US)
#
#  RET: json string {"lastprice" : <float>} 

use CGI;
use JSON;
use Stocks::Quote;

my $q = new CGI;
print $q->header('application/json');
my $symbol = $q->param('symbol') || 'BNS'; 
my $exch = $q->param('exch') || 'TSX';
my ($json, $quote);

if ( $symbol && $exch ) {
    $quote = Stocks::Quote::get ( symbol => $symbol, exchange => $exchange );
    $json->{lastprice} = $quote->last();
}

print to_json($json);

#print '{"lastprice" : '. $json->{lastprice} . '}';


