#!/usr/bin/perl
#
# get boolean parameters for port and save them to DB
# Name: 'active', 'email_flag', 'cashonly'
# Value : 0 | 1
# id : port id

use Log::Any::Adapter;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use CGI;
use Stocks::Portfolio;
Log::Any::Adapter->set('Log4perl');
Log::Log4perl->easy_init($ERROR);

my $log = Log::Any->get_logger();
my %bool = ('false' => 0, 'true' =>1);
my $query = new CGI;
my $id = $query->param('id');

$log->error ("just checking....");
$log->error ("'id' is required \n") unless $id;
$log->error ("'name' is required \n") unless $name;
$log->error ("'val' is required \n") unless $val;

my $name = $query->param('name');
my $val = $query->param('val');
my $val = $bool{$val} if $val;

my $port = Stocks::Portfolio::get( id => $id );

if ( ref $port ) {
    $port->active($val) if $name eq 'active';
    $port->cashonly($val) if $name eq 'cashonly';
    $port->email_flag($val) if $name eq 'email_flag';
    $port->save();
} else {
   $log->error ("port with id '$id' was not found \n");
}

