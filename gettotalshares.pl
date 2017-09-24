#!/usr/bin/perl
#
# get 3 parameters from jquery call (addTransaction1.mas) :
#  portid : portfolio id
#  symbol : # shares bought/sold
#  ecxh   : exchange where this equity is traded: TSX | other (US)
#
#  RET: json string {"shares" : <number>} 

use CGI;
use JSON;
use Stocks::Portfolio;

my $q = new CGI;
print $q->header('application/json');
my $symbol = $q->param('symbol');
my $exch = $q->param('exch');
my $portid = $q->param('portid');
my $shares = 0;
my $json;

#$portid=1;
#$symbol='BNS';
#$exch='TSX';

if ( $symbol && $exch ) {
    my $port = Stocks::Portfolio::get (id => $portid);
    foreach my $ass ( @{$port->assets} ){
	if ($ass->{symbol} eq $symbol && $ass->{exchange} eq $exch) {
	    $shares = $ass->{number};
	    last;
	}
    }
}


$json->{shares} = $shares;
print to_json($json);

#print '{"shares" : '. $shares . '}';


