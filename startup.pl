# FN startup file
# 
# Set up mod_perl environment and load all the stuff that can be loaded
#
# by Dmitri Ostapenko, d@perlnow.com

use strict;
use lib qw(/var/www/perl /usr/local/lib/i386-linux-gnu/perl);

use CGI;
use Stocks::Config qw($CONFIG);
use Apache::DBI;
use Apache2::Request;

# This will create persistent db handle which will be ready to use on first call to DB

Apache::DBI->connect_on_init($CONFIG->{db}{dsn}, $CONFIG->{db}{user}, $CONFIG->{db}{pass}, $CONFIG->{db}{options});

# Dump debug info into error log
$Apache::DBI::DEBUG = 0;

# Site-wide modules are loaded next:

use Stocks::Startup;


1;

