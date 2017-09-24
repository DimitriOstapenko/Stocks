#!/usr/bin/perl
#
# csvquote BCE.TO
# 

    use HTTP::Lite;
#    use MIME::Base64;
    use Data::Dumper;
    use strict;

#| symbol      : s0
#| exchange    : x0
#| currency    : 
#| timestamp   : d2 + t1
#| method      : yhoocsv
#| net         : c1
#| p_change    : p2
#| open        : o
#| close       : p
#| last        : l1
#| price       : l1
#| high        : h0
#| low         : g0
#| ask         : b2
#| bid         : b3
#| volume      : v0
#| avg_vol     : a2
#| eps         : e7
#| pe          : r
#| cap         : j1 (j3 real time)
#| year_low    : j0
#| year_high   : k0
#| name        : n0
#| div         : d
#| div_yield   : y
#| div_date    : r1
#| ex_div      : q

    my ( $symbol);
    my ( @keys ) = qw(symbol exchange date time net p_change open close price high low ask bid volume avg_vol eps pe cap year_low year_high name div div_yield div_date ex_div);

    $symbol = $ARGV[0] || 'BNS.TO';

    my $http = new HTTP::Lite;
    my $url = 'http://download.finance.yahoo.com/d/quotes.csv?f=s0x0d1t1c1p2opl1h0g0b2b3v0a2e7rj1j0k0n0dyr1q&e=csv&s='. $symbol;

    my $req = $http->request( $url ) or die "Unable to get document: $!";
    die "Request failed ($req): ".$http->status_message() if $req ne "200";

    my $quote = $http->body();

    $quote =~ s/N\/A/0/g;
    $quote =~ tr/"+%//d;

   my (@vals) = split (',', $quote);
   my ($dt,$tm) = @vals[2,3];
   my (@d) = split("/", $dt);
   $dt = $d[2].'-'.$d[0].'-'.$d[1];
   my $ts = $dt .' '. $tm;

   my %q = map{$keys[$_],$vals[$_]} 0..@keys;

# add missing keys
   $q{timestamp} = $ts;
   $q{currency} = 'CAD';
   $q{method} = 'yhoocsv';
   $q{last} = $q{price};

#for my $key ( @keys ) {
#   print $key , ':', $q{$key}, "\n"; 
#}

print join "\n", %q;
