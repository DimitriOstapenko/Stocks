# Get symbol quote (US and Canada among others) from yahoo site using Finance::Quote
#
# by Dmitri Ostapenko, d@perlnow.com   

package Stocks::Quote;

$VERSION = 1.23;

use strict;
use Moose;

with qw(Stocks::Base);

use Stocks::Types qw( All );
use Stocks::DB;
use Stocks::Utils;
use Carp;
use HTTP::Lite;
#use Smart::Comments;

use Stocks::Config qw($CONFIG);
use Finance::Quote;
use Data::Dumper;
use Time::Local;
use namespace::autoclean;


my $QUOTE_LIFE = $CONFIG->{quote}{life};

#+-----------+--------------+------+-----+---------------------+----------------+
#| Field     | Type         | Null | Key | Default             | Extra          |
#+-----------+--------------+------+-----+---------------------+----------------+
#| id        | int(11)      | NO   | PRI | NULL                | auto_increment | 
#| symbol    | varchar(11)  | NO   | UNI |                     |                | 
#| exchange  | varchar(10)  | NO   |     | TSX                 |                | 
#| currency  | varchar(10)  | NO   |     | CDN                 |                | 
#| timestamp | datetime     | NO   |     | 1900-01-01 00:00:00 |                | 
#| method    | varchar(20)  | NO   |     |                     |                | 
#| net       | double(16,5) | NO   |     | 0.00000             |                | 
#| p_change  | double(16,5) | NO   |     | 0.00000             |                | 
#| open      | double(16,5) | NO   |     | 0.00000             |                | 
#| close     | double(16,5) | NO   |     | 0.00000             |                | 
#| last      | double(16,5) | NO   |     | 0.00000             |                | 
#| price     | double(16,5) | NO   |     | 0.00000             |                | 
#| high      | double(16,5) | NO   |     | 0.00000             |                | 
#| low       | double(16,5) | NO   |     | 0.00000             |                | 
#| ask       | double(16,5) | NO   |     | 0.00000             |                | 
#| bid       | double(16,5) | NO   |     | 0.00000             |                | 
#| volume    | int(11)      | NO   |     | 0                   |                | 
#| avg_vol   | int(11)      | NO   |     | 0                   |                | 
#| eps       | double(16,5) | NO   |     | 0.00000             |                | 
#| pe        | double(16,5) | NO   |     | 0.00000             |                | 
#| cap       | double(16,5) | NO   |     | 0.00000             |                | 
#| year_low  | double(16,5) | NO   |     | 0.00000             |                | 
#| year_high | double(16,5) | NO   |     | 0.00000             |                | 
#| name      | varchar(80)  | NO   |     |                     |                | 
#| div       | double(16,5) | NO   |     | 0.00000             |                | 
#| div_yield | double(16,5) | NO   |     | 0.00000             |                | 
#| div_date  | varchar(20)  | NO   |     | ''                  |                | 
#| ex_div    | varchar(20)  | NO   |     | ''                  |                | 
#+-----------+--------------+------+-----+---------------------+----------------+


#
# Objects of this class will have following attributes:

	has 'id' => (is => 'rw', isa => 'PosInt' );                                 # port id
	has 'symbol' => (is => 'ro', isa => 'Str');                                 # full stock symbol
	has 'exchange' => (is => 'rw', isa => 'Str');                               # exchange string (for full list see Finance::Quote)
	has 'currency' => (is => 'rw', isa => 'CurType', default => 'CAD');         # CAD/USD
	has 'timestamp' => (is => 'rw', isa => 'TimeStamp', 
	     default=>'1900-01-01 00:00:00');           			    # quote timestamp (based on isodate + time)
	has 'method' => (is => 'rw',  isa => 'Str');				    # method used to get the quote: eg 'yahoo'
	has 'net' => (is => 'rw', isa => 'Num', default=>0.0); 		            # $ change
	has 'p_change' => (is => 'rw', isa => 'PcFloat',default=>0.0);     	    # % change
	has 'open' => (is => 'rw', isa => 'Num',default=>0.0);  		    # $ price at open 
	has 'close' => (is => 'rw', isa => 'Num',default=>0.0);			    # prev. day's closing price
	has 'last' => (is => 'rw', isa => 'Num', default => 0.0);  		    # last price
	has 'price' => (is => 'rw', isa => 'Num',default=>0.0);			    # price
	has 'high' => (is => 'rw', isa => 'Num', default => 0.0);		    # day's high
	has 'low' => (is => 'rw', isa => 'Num', default=> 0.0);		  	    # day's low
	has 'ask' => (is => 'rw', isa =>'Num', default => 0.0);		            # last asking price
	has 'bid' => (is => 'rw', isa => 'Num', default => 0.0);		    # last bid price
	has 'volume' => (is => 'rw', isa => 'Int', default => 0);		    # day's volume
	has 'avg_vol' => (is => 'rw', isa => 'Int', default => 0);		    # 3mo avg vol
	has 'eps' => (is => 'rw', isa => 'Num', default => 0.0);		    # earnings per share			
	has 'pe' => (is => 'rw', isa => 'Num', default => 0.0); 	            # price to earnings	
	has 'cap' => (is => 'rw', isa => 'Num', default => 0); 			    # market cap
	has 'year_low' => (is => 'rw', isa => 'Maybe[Num]');			    # lowest price this year 
	has 'year_high' => (is => 'rw', isa => 'Maybe[Num]');			    # highest price this year 
	has 'name' => (is => 'rw', isa => 'Str');				    # company name	
	has 'div' => (is => 'rw', isa => 'Maybe[PosFloat]', default=>0.0);          # $/share/yr
	has 'div_yield' => (is => 'rw', isa => 'Maybe[PosFloat]', default=>0.0);  # % yield
	has 'div_date' => (is => 'rw', isa => 'Str'); 				    # Date of the next dividend
	has 'ex_div' => (is => 'rw', isa => 'Str');    		                    # Last dividend date	
	has '__errormsg' => (is => 'rw', isa => 'Str');				    # quote error



__PACKAGE__->meta->make_immutable;
no Moose;

sub _table { 'quote' }

# Get quote from DB; Cache it. Delete cache and re-quote if cache expired
# ARG: id || symbol & exchange ('TSX', 'NYSE', 'AMEX', 'NASD', '' );
# RET: quote obj

sub get {
   my (%arg) = @_;
   my $id = $arg{'id'};
   my $symbol = uc $arg{'symbol'};
   my $exchange =  $arg{'exchange'} || 'TSX';
   my $where = "exchange='$exchange' AND ";
   my $quote = undef;

   croak 'id or symbol is required' unless ($id || $symbol);

#  normalize for yahoo quotes all but .NYM and .CMX
   $symbol =~ tr/\./\-/ unless ($symbol =~ /\.NYM$/ or $symbol =~ /\.CMX$/);

   if ( $id ) {
      $where .= 'id='.$id
   } else {
      $where .= "symbol='$symbol'"
   }

#  print "**** going to read from DB quote for $symbol *** \n";
   my $row=undef;
   $row = Stocks::DB::select (table => _table,
   			      where => $where,
		              limit => 1
   			     );

### print "got row from db: " :  $row

   $quote = __PACKAGE__->new ( $row ) if ref $row;

   if ( $quote && $quote->price ) { # delete expired quotes during business hours

      $quote->delete if $quote->_cache_expired();

   } else {  		  # Get & save quotes not present in DB 
#     print "will fetch quote for $symbol \n";
     my $exch = lc $exchange;
     $exch = 'canada' if ($exch eq 'tsx');
     eval {$quote = fetch (symbol => $symbol, exchange => $exch); };

     if ($quote && $symbol eq 'XAUUSD=X') {
        my $lq = get(symbol=>'XAUUSD_LAST', exchange => 'NYSE');
        $quote->close($lq->price());
 
 # !!! Temp override of bad yahoo gold quote: Price/Oz in USD
        my $tmp = $lq->price();
        $quote->price($tmp); $quote->last($tmp); $quote->open($tmp);
     }

     if ($quote && $symbol eq 'USDCAD=X') {
	$quote->price(1) unless $quote->price();
     }

    $quote->exchange('TSX') if ($quote && lc $quote->exchange eq 'canada');
    $quote->save if $quote && $quote->price;
   }

   return $quote;
}

# Fetch delayed quote using Finance::Quote; fill missing fields in quote object
# Class method
# ARG: symbol, exchange
# RET: quote obj 

sub fetch {
   my (%arg) = @_;
   my $symbol = uc $arg{symbol};
   my $exchange = uc $arg{exchange} || 'TSX';
   my ( @keys ) = qw(symbol exchange date time net p_change open close price high low ask bid volume avg_vol eps pe cap year_low year_high name div div_yield div_date ex_div);

   croak 'symbol is required' unless $symbol;

   my $self = __PACKAGE__->new( symbol => $symbol, exchange => $exchange);

   if ($symbol =~ /\d(C|P)$/) {        # no quotes for options
      my $errmsg = 'fetch: No Quote for option : '. $symbol;
      $self->__errormsg($errmsg);
      return $self;
   }

# all except indices, XAUUSD=X and USDCAD=X EURCAD=X
   $symbol .= '.TO' unless ($symbol =~ /\.TO$/ || $symbol =~ /^\^/ || $symbol =~ /\=/ || $symbol =~ /LAST$/);

   my $http = new HTTP::Lite;
   my $url = 'http://download.finance.yahoo.com/d/quotes.csv?f=s0x0d1t1c1p2opl1h0g0b2b3v0a2e7rj1j0k0n0dyr1q&e=csv&s='. $symbol;

   my $req = $http->request( $url ) or die "Unable to get document: $!";

   unless ($req eq '200') {
       my $errmsg = 'fetch: Quote request failed :'. $http->status_message();
       $self->__errormsg($errmsg);
       return $self
   }

   my $quote = $http->body();

   $quote =~ s/N\/A/0/g;
   $quote =~ tr/"+%//d;

   my (@vals) = split (',', $quote);
   my ($dt,$tm) = @vals[2,3];
   my (@d) = split("/", $dt);
   
   if ($d[0] && $d[1] && $d[2]) {
      $dt = $d[2].'-'.$d[0].'-'.$d[1] if @d;
   } 
   my $ts = $dt .' '. $tm;

#foreach my $i (0..@keys-1 ){
#   print ' key, val :', $i,':', $keys[$i], ':', $vals[$i], "\n";
#   }

   my %quote = map{$keys[$_],$vals[$_]} 0..@keys-1;


# add missing keys
   $quote{timestamp} = $ts;
   $quote{currency} = 'CAD';
   $quote{method} = 'yhoocsv';
   $quote{last} = $quote{price};

   if ($quote{'cap'} && $quote{'cap'} =~ /m/i) {
      $quote{'cap'} =~ s/m//i;
      $quote{'cap'} *= 1000000;
   }

   if ($quote{'cap'} && $quote{'cap'} =~ /b/i) {
      $quote{'cap'} =~ s/b//i;
      $quote{'cap'} *= 1000000000;
   }

   unless ( $quote{'price'} > 0 ) {
       my $errmsg = $quote{'errormsg'} || 'could not get the quote';
       $self->__errormsg($errmsg);
       return $self
   }


   my $keyval = $self->get_all_attributes();
   my @attr = keys %$keyval;
   
#foreach my $key (sort keys %quote) {
#  print $key , ':', $quote{$key}, "\n";
#}

# 1-st 3 fields are ro
   foreach my $key ( @attr ) {
      next if $key eq 'symbol' or $key eq 'exchange';
      $self->$key($quote{$key}) if defined $quote{$key};
   }
   
   return $self

} # fetch

# Find records matching given criteria
# Class method
# ARGS: field : field to search on
#       type: Str, Int, Num (LIKE queries for Str)
#       value : value for the field
#       order_by : sort field
#       order : sort order (ASC/DESC) (opt) def ASC 
#       returns : type of result returned : 'hash', 'array', 'scalar' 
# RET: hashref/arrayref/scalar
#
sub find {
  my %arg =  @_;
  $arg{table} =  _table();

  _find ( %arg );

} # find

# Is there record in a DB for this quote?
# ARG: none
# RET: bool

sub found {
  my $self = shift;
  my $where;

  return unless $self->id || ($self->symbol && $self->exchange);

  if ( $self->id() ) {
     $where = 'id='.$self->id();
  } else {
     $where = "symbol='" .$self->symbol. "' AND exchange='". $self->exchange. "'";
  }

  my $id = Stocks::DB::select (table => _table(),
  			        fields => [qw(id)],
			   	where => $where,
			   	returns => 'scalar'
			   	);

 $self->id ($id) if $id;

 return $id;
} # found

# Delete all quotes from quote table for given exchange
# Class method
# ARG: exchange : exchange to delete

sub delete_all {
  my %arg = @_;
  my $exchange = $arg{exchange} || 'TSX';

  my $id = Stocks::DB::delete ( table => _table, 
  				field => 'exchange', 
				value => $exchange
			      );
} #delete_all

  
# Delete quotes older than $CONFIG{quote}{delete_after} hours
# ARG: none ($CONFIG{quote}{delete_after} must be set)
# RET: number of rows
  
sub delete_expired {
  my $delete_after =  $CONFIG->{quote}{delete_after};

  croak "'delete_after' must be in CONFIG->{quote}" unless $delete_after;

# As this runs during business hours, let's clean out old quotes (older than 4 hrs)
# As a precaution, we'll check to make sure this is done during business hours

  my $where = " age(now(),timestamp) > '$delete_after'"
	     .' AND EXTRACT(DOW FROM now())>0 AND EXTRACT(DOW FROM now())<7 '
	     .' AND EXTRACT(HOUR FROM now())<17 AND EXTRACT(HOUR FROM now())>9'
	     ." AND symbol NOT LIKE 'USDCAD%' AND symbol NOT LIKE 'XAUUSD%'";

  my $rows_deleted = Stocks::DB::delete (table => _table,
  		   		         where => $where
		     		  	);

  return $rows_deleted
} # delete_older_than

# Cache usd/cad rate for use next day
# Set date in the future to prevent deletion by delete_expired
# ARG: none
# RET: none

sub cache_usdcad {
   my $ind = $CONFIG->{indices};
   my $curusdcad = get ( symbol=> $ind->{usdcad}{symbol}, exchange => $ind->{usdcad}{exchange});
   my $last_usdcad = get ( symbol=> $ind->{usdcad_last}{symbol}, exchange => $ind->{usdcad_last}{exchange});

   my $ts = DateTime->today( time_zone => 'local');
   $ts->add(days => 1);

   $last_usdcad->timestamp ( $ts->ymd.' 23:45:00' );
   $last_usdcad->price ( $curusdcad->price );
   $last_usdcad->last ( $curusdcad->price );

   $last_usdcad->save;

} # cache_usd

# Cache eur/cad rate for use next day
# Set date in the future to prevent deletion by delete_expired
# ARG: none
# RET: none

sub cache_eurcad {
   my $ind = $CONFIG->{indices};
   my $cureurcad = get ( symbol=> $ind->{eurcad}{symbol}, exchange => $ind->{eurcad}{exchange});
   my $last_eurcad = get ( symbol=> $ind->{eurcad_last}{symbol}, exchange => $ind->{eurcad_last}{exchange});

   my $ts = DateTime->today( time_zone => 'local');
   $ts->add(days => 1);

   $last_eurcad->timestamp ( $ts->ymd.' 23:45:00' );
   $last_eurcad->price ( $cureurcad->price );
   $last_eurcad->last ( $cureurcad->price );

   $last_eurcad->save;

} # cache_eurcad

# Cache XAUUSD (gold) price for use next day
# Set date in the future to prevent deletion by delete_expired
# ARG: none
# RET: none

sub cache_xauusd {
   my $ind = $CONFIG->{indices};
   my $cur = get ( symbol=> $ind->{gold}{symbol}, exchange => $ind->{gold}{exchange});
   my $last = get ( symbol=> $ind->{gold_last}{symbol}, exchange => $ind->{gold}{exchange});

   my $ts = DateTime->today( time_zone => 'local');
   $ts->add(days => 1);

   $last->timestamp ( $ts->ymd.' 23:45:00' );
   $last->price ( $cur->price );
   $last->last ( $cur->price );

   $last->save;

} # cache_xauusd

#____________________Private Methods____________________

# Insert DB record
# Private object method
# ARGS: none
# EFFECTS: inserts row into DB; 
# RET: id of inserted record
#
sub _insert {
  my $self = shift;
  my $keyval = $self->get_attributes();
  my $id;

  eval {
  $id = Stocks::DB::insert (
  			    table => _table(),
  			    keyval => $keyval 
			  );
	};

  print '_insert error: could not insert record: ', $self->dump() unless $id;

  return $id
} #_insert

# Update DB record
# Private object method
# ARGS: none
# EFFECTS: updates existing DB record
#          sets "errormsg" property in case of failure
# RET:id of the updated record 

sub _update {
  my $self = shift;
  my $id = $self->id;
  my $keyval = $self->get_attributes();

  croak '_update error: could not update record - "id" was not defined' unless $id;

  my $updated_id = Stocks::DB::update (
  				   table => _table(),
  				   keyval => $keyval, 
				   where => 'id='.$id
				  );
  
  croak '_update error: could not update record: ', $self->dump() unless $updated_id;

  return $updated_id 

}
# Did cache expire?
# Obj method
# ARG: timestamp field must be set
# RET: bool

sub _cache_expired {
  my $self = shift;

  return unless $self->timestamp;
  return if $self->symbol eq $CONFIG->{indices}{usdcad_last}{symbol};
  return if $self->symbol eq $CONFIG->{indices}{gold_last}{symbol};

# unix timestamps
  my $now = timelocal(localtime());
  my $quote_ts = Stocks::Utils::toUnixTS ($self->timestamp);

  my @now = localtime ();
  my $hrmin = $now[2] + $now[1] / 60;
  my $dow  = $now[6];
  my $mstart = 9.5; # market open time dec 
  my $mend = 17;  # market close time dec

# Business hours:
  if ($hrmin > $mstart and $hrmin < $mend and $dow > 0 and $dow < 6)  {
      if ($now - $quote_ts >  $QUOTE_LIFE ){
### now - quote_ts : $now - $quote_ts
### QUOTE_LIFE : $QUOTE_LIFE
         return 1;
      }  
  }

# Date set is in the future (commodities yahoo futures)
#  return 1 if ($now - $quote_ts < 0 );

return 
}


1;


__END__
 
=head1 NAME
 
Stocks::Quote -- Stocks Quote Interface 
 
=head1 SYNOPSIS

my $q = Stocks::Quote->new ( symbol => 'RY.TO', exchange => 'canada');

$q->get;
$q->save;
$q->delete;

=head1 INTERFACE

=head2 constructor

=head2 Save

Saves portfolio into DB

=head2 dbValues

=head2 idFound

=head1 AUTHOR

Dimitri Ostapenko (d@perlnow.com)
 
=cut
