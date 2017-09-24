#
#%% PortfolioHistory interface functions using Moose
#
# by Dmitri Ostapenko, d@perlnow.com   

package Stocks::PortfolioHistory;

$VERSION = 1.00;

use strict;
use Moose; 
use Stocks::Types qw( All );

with qw(Stocks::Base);

use Stocks::DB;
use Carp;
use Smart::Comments;


#+----------+-------------------------------------+------+-----+------------+----------------+
#| Field    | Type                                | Null | Key | Default    | Extra          |
#+----------+-------------------------------------+------+-----+------------+----------------+
#| id       | int(11)                             | NO   | PRI | NULL       | auto_increment | 
#| portid   | int(11)                             | NO   |     | NULL       |                | 
#| date     | date                                | NO   | MUL | 0000-00-00 |                | 
#| symbol   | varchar(11)                         | NO   | MUL |            |                | 
#| exchange | enum('TSX','NYSE','AMEX','NASD','') | NO   |     | TSX        |                | 
#| acb      | double(16,5)                        | NO   |     | NULL       |                | 
#| price    | double(16,5)                        | NO   |     | NULL       |                | 
#| number   | double(16,5)                        | NO   |     | 0.00000    |                | 
#| fx_rate  | double(16,5)                        | NO   |     | 1.00000    |                | 
#| descr    | varchar(120)                        | YES  |     | NULL       |                | 
#+----------+-------------------------------------+------+-----+------------+----------------+


#
# Objects of this class will have following attributes:

    has 'id' => (is => 'rw', isa => 'PosInt');                          # PortfolioHistory id
    has 'portid' => (is => 'ro', isa => 'PosInt',required=>1);          # Portfolio id
    has 'date' => (is => 'ro', isa => 'Date', required=> 1);  		# Date
    has 'symbol' => (is => 'ro', isa => 'Str', required=>1);            # Stock symbol or 'cash'
    has 'exchange' => (is => 'ro', isa => 'Exchange',default => 'TSX'); # Exchange of the stock
    has 'acb' => (is => 'ro', isa => 'PosFloat', required=>1);          # ACB/share 
    has 'price' => (is => 'ro', isa => 'PosFloat', required=>1);        # Current Price 
    has 'number' => (is => 'ro', isa => 'Num', required=>1);            # Total Number of shares for this symbol
    has 'fx_rate' => (is => 'ro', isa=>'PosFloat', default=> 1);        # Exchange rate if not in currency of the portfolio 
    has 'descr' => (is => 'ro', isa => 'Str', default=>'');             # Comment

__PACKAGE__->meta->make_immutable;
no Moose;

sub _table { 'portfolio_history' }

# Get row with given id
# Class method
# ARG: id
# RET: object

sub get {
  my (%arg) = @_;
  my $id = $arg{id};
  
  
  croak "id is required" unless $id;

  my $row = Stocks::DB::select ( table => _table(), 
   			      	  where => "id=$id",
			          limit => 1
			        );

  return unless ref $row;
  return __PACKAGE__->new( $row );

} #Get


# Get latest position values for given portfolio
# Class method
# ARG: portid => 'num'
# RET: arrayref => {date,symbol,exchange,number,value}

sub getPortLatestPositions {
  my (%arg) = @_;
  my $portid = $arg{portid};

  croak "'portid' is rquired " unless $portid;

  my $qry = 'SELECT date,symbol,date,number, (price*number*fx_rate) AS value FROM '
  	    . _table() 
	    . ' WHERE portid=$portid AND date=(SELECT MAX(date) FROM '._table().') '
	    .' ORDER BY value DESC';
  
  my $rows = Stocks::DB::select ( sql => $qry );

  return $rows 
} #getLatest

# Get values for each symbol in each portfolio for most recent date
# Class Method
# ARG: none
# RET: arrayref sorted by value, descending  [portid, date, symbol, exchange, number, value ]

sub getLatestPositions {

  my $qry = 'SELECT portid,date,symbol,exchange,number,(price*number*fx_rate) AS value FROM '
  	    ._table ()
  	    .' WHERE date=(SELECT MAX(date) FROM '. _table() .')'
	    .' ORDER BY value DESC';

  my $rows = Stocks::DB::select ( sql => $qry );

  return $rows 
} # getLatestPositions

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


# Is record for this user in a DB?
# ARG: none
# RET: bool

sub found {
  my $self = shift;
  my $where;

  return unless $self->id || ($self->portid && $self->symbol && $self->date);

  if ( $self->id() ) {
     $where = 'id='.$self->id();
  } else {
     $where = 'portid='.$self->portid." AND symbol='". $self->symbol. "' AND date='". $self->date. "'";
  }

  my $id = Stocks::DB::select (table => _table(),
  			        fields => [qw(id)],
			   	where => $where,
			   	returns => 'scalar'
			   	);

  $self->id ($id) if $id;
  return $id;

} # found

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

  my $id = Stocks::DB::insert (
  			    table => _table(),
  			    keyval => $keyval 
			  );

  croak '_insert error: could not insert record: ', $self->dump() unless $id;

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

  my $where = "id=$id";

  my $updated_id = Stocks::DB::update (
  				   table => _table(),
  				   keyval => $keyval, 
				   where => $where
				  );
  
  croak '_update error: could not update record: ', $self->dump() unless $updated_id;

  return $updated_id 

}

1;

__END__
 
=head1 NAME
 
Stocks::PortfolioHistory -- Stocks PortfolioHistory Interface 
 
=head1 SYNOPSIS

use Stocks::PortfolioHistory;

my $p = Stocks::PortfolioHistory->new(  
  				 portid => 1,
				 symbol => 'RY',
				 date   => '2010-01-01',
				 acb    => 51.00,
				 price  => 49.20,
				 number => 2500
			       );
$p->dump;
$p->save ();

my $ph = Stocks::FPortfolioHistory::Get (id => 7576);
my $positions = Stocks::FPortfolioHistory::GetLatest(portid => 1);
my $positions = Stocks::FPortfolioHistory::GetPositionsByValue();

print "\nLatest portfolio values: \n\n";
my $ttl = 0;
foreach my $pos ( @$positions ) {
   print "$pos->{symbol} : $pos->{exchange} - $pos->{date} : $pos->{value}\n";
   $ttl += $pos->{value};
}

print "\nGrand Total: ", $ttl, "\n\n";


=head1 INTERFACE

=head2 constructor

=head2 save

Saves transaction into DB

=head2 delete

==head2 save 

==Dump

==_insert

==_update

=head1 AUTHOR

Dimitri Ostapenko (d@perlnow.com)
 
=cut
