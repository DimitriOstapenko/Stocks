package Stocks::Config;

use strict;
use vars     qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $CONFIG);

BEGIN {
  use Exporter ();

  $VERSION     = do { my @r = (q$Revision: 1.6 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 

  @ISA         = qw(Exporter);
  @EXPORT      = qw($CONFIG);
}

$CONFIG =
   {
         dirs => {
		   charts => '/home/stocks/public_html/charts',
                 },

         quote => {
		   life => 30*60, # min in sec
		   'delete_after' => '4 hours 0 minutes',
	 	  },

          mdb => {   						# MySQL
                 dsn => "DBI:mysql:stocks:localhost",
                 user => 'root',
                 pass => 'm'
                 },
	  db => {						# Pg

	        dsn => 'dbi:Pg:dbname=stocks;host=localhost',
        	user => 'stocks',
        	pass =>  'm',
        	options => { ShowErrorStatement => 0, # append stmt text details to error message in die() or warn()
                	     RaiseError => 0, # don't die on errors
                     	     PrintError => 0, # warn() on errors
                     	     AutoCommit => 1, # commit to DB immediately
                     	     pg_enable_utf8 => 1,  # enable utf by default
                  	    },
	        },

          apacheconf => {
                           debug_log => '/home/perlnow/dbug.log',
                        }, 

	  user => {
	             guest_username => 'nobody',
		  },

          indices => {
 		 tsx => {symbol=> '^GSPTSE', exchange => 'TSX'},
                 dow => {symbol=> '^DJI', exchange => 'NYSE'},
                 nasd => {symbol=> '^IXIC', exchange => 'NASD'},
                 usdcad => {symbol=> 'USDCAD=X', exchange => 'NYSE'},
                 usdcad_last => {symbol=> 'USDCAD_LAST', exchange => 'NYSE'},
                 eurcad => {symbol=> 'EURCAD=X', exchange => 'NYSE'},
                 eurcad_last => {symbol=> 'EURCAD_LAST', exchange => 'NYSE'},
                 crude => {symbol=> 'CLJ12.NYM', exchange => 'NYSE'}, # Apr
                 ngas => {symbol=> 'NGJ12.NYM', exchange => 'NYSE'},  # Apr
                 gold => {symbol=> 'XAUUSD=X', exchange => 'NYSE'}, 
                 gold_last => {symbol=> 'XAUUSD_LAST', exchange => 'NYSE'}, 
		 },

    };


1;

__END__

=head1 NAME

Stocks::Config

=head1 DESCRIPTION

This module is a good place to put static configuration that wont change often.

The main purpose of this module is to export $CONFIG which contains the site
configuration information.

=head1 SYNOPSIS

=head1 INTERFACE

=head1 AUTHOR

Dmitri Ostapenko (d@perlnow.com)
