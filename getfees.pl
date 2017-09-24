#!/usr/bin/perl
#
# get 3 parameters from jquery call (addTransaction1.mas) :
#  shares : # shares bought/sold
#  exch   : exchange where this equity is traded: TSX | other (US)
#  id     : broker id in broker table
#
#  RET: json string {"fees" : <number>} 

use CGI;
use JSON;
use Stocks::Broker;

my $q = new CGI;
print $q->header('application/json');
my $shares = $q->param('shares');
my $brokerid = $q->param('id');
my $exch = $q->param('exch');
my $market = $exch eq 'TSX' ? 'CA':'US';

my $broker = Stocks::Broker::get( id => $brokerid);
my $fees = $broker->getFee( shares => $shares, market => $market);

my $json->{fees} = $fees;
print to_json($json);

#print '{"fees" : '. $fees . '}';
