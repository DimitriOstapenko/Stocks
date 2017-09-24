#!/usr/bin/perl

use strict;
use Data::Dumper;
use XML::RSS::Liberal;
use LWP::Simple;
use URI::Escape;

my $rss = XML::RSS::Liberal->new;

my $url='http://finance.yahoo.com/rss/headline?s=BNS';
my $content =  get ($url);

$rss->parse( $content );

 foreach my $item ( @{$rss->{items}} ) {
     my $title = $item->{title};
     my $url = $item->{link};
     my $pdate = $item->{'pubDate'};
     my $descr = $item->{'description'};
     next unless $url;
     $url = uri_unescape($url);
     print '<div style="font-size:0.8em; width:590px;"><a href="'.$url.'" target="_new"><b>'.$title."</b></a> <br><span style='font-size: 0.55em'> $pdate </span></div>";
     my ($abstract,$rest) = split ("\n",$descr);
     print "<div style='width: 590px; font-size: 0.7em;'>", $abstract, "</div><br>\n";
  }


