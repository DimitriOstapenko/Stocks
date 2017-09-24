#%% Stocks Transaction History interface functions
#
# by Dmitri Ostapenko, d@perlnow.com   

package Stocks::TransactionHistory;

$VERSION = 1.00;

use strict;
use Moose; 

with qw(Stocks::Base);

use Stocks::Types qw( All );
use Stocks::DB;
use Carp;
#use Smart::Comments;

#                                     Table "public.transaction_history"
#  Column   |              Type              |                            Modifiers                             
#-----------+--------------------------------+------------------------------------------------------------------
# id        | integer                        | not null default nextval('transaction_history_id_seq'::regclass)
# portid    | integer                        | not null
# ttype     | smallint                       | not null
# ttype_str | character varying(80)          | default NULL::character varying
# date      | timestamp(0) without time zone | not null
# setl_date | timestamp(0) without time zone | 
# symbol    | character varying(11)          | not null
# exchange  | exchangetype                   | 
# price     | double precision               | not null
# number    | double precision               | not null
# fx_rate   | double precision               | not null default 1::double precision
# fees      | double precision               | 
# amount    | double precision               | 
# descr     | character varying(120)         | default NULL::character varying
#Indexes:
#    "transaction_history_pkey" PRIMARY KEY, btree (id)


#
# Objects of this class will have following attributes:

    has 'id' => (is => 'rw', isa => 'PosInt');                          # Transaction id
    has 'portid' => (is => 'ro', isa => 'PosInt',required=>1);          # Portfolio id
    has 'ttype' => (is => 'ro', isa => 'TType', required=>1);           # Transaction type (0:cash; 1:buy/sell; 2:div 3:int) 
    has 'ttype_str' => (is => 'ro', isa => 'Maybe[Str]',default=>'');   # Transaction type descriptor 
    has 'date' => (is => 'ro', isa => 'DateTime_',required=>1);   	# Transaction date/time
    has 'setl_date' => (is => 'ro', isa => 'DateTime_');   		# Settlement date/time
    has 'symbol' => (is => 'ro', isa => 'Str', required=>1);            # Stock symbol or 'cash'
    has 'exchange' => (is => 'ro', isa => 'Exchange',default => '');    # Exchange of the stock
    has 'price' => (is => 'ro', isa => 'PosFloat', required=>1);        # Price at wich stock was bought/sold
    has 'number' => (is => 'ro', isa => 'Num', required=>1);            # Number of shares bought/sold +/-
    has 'fx_rate' => (is => 'ro', isa=>'PosFloat', default=> 1);        # Exchange rate if not in currency of the portfolio 
    has 'fees' => (is => 'ro', isa => 'PosFloat', default=>0);		# Transaction fees
    has 'amount' => (is => 'rw', isa => 'Maybe[Num]', default=>0);  		# Equity in/out this transaction (computed)
    has 'descr' => (is => 'ro', isa => 'Maybe[Str]', default=>'');      # Comment


__PACKAGE__->meta->make_immutable;
no Moose;

sub _table { 'transaction_history' }

# Get transaction with given id
# Class method
# ARG: id
# RET: transaction object

sub get {
  my (%arg) = @_;
  my $id = $arg{id};

  croak "'id' must be defined" unless $id;

  my $row = Stocks::DB::select ( table => _table(),
  				 where => 'id='.$id,
				 limit => 1
				);

  return unless $row->{id};
  return __PACKAGE__->new( $row );

} #Get

# Get latest transaction of the given type
# Class method
# ARG: portid => 'num'
#      ttype => 'num'
# RET: transaction object

sub getLatest {
  my (%arg) = @_;
  my $portid = $arg{portid};
  my $ttype = $arg{ttype};

  croak "'portid' is required" unless $portid;
  
  my $where = 'portid='.$portid;
  $where .= ' AND ttype='.$ttype if $ttype;

  my $row  = Stocks::DB::select ( table => _table(),
  				  where => $where,
				  order_by => 'date DESC',
				  limit => 1
				 );

  return __PACKAGE__->new ( $row ) if $row; 

} #getLatest

# Get oldest transaction of the given type
# Class method
# ARG: portid => 'num'
#      ttype => 'num'
# RET: transaction object

sub getOldest {
  my (%arg) = @_;
  my $portid = $arg{portid};
  my $ttype = $arg{ttype};

  croak "'portid' is required" unless $portid;
  my $where = 'portid='.$portid;
  $where .= ' AND ttype='.$ttype if $ttype;

  my $row  = Stocks::DB::select ( table => _table(),
  				  where => $where,
				  order_by => 'date',
				  limit => 1
				 );

  return __PACKAGE__->new ( $row ) if $row; 

} #getOldest

# Get active unique symbols from all portfolios
# Class method
# ARG: none
# RET: hashref
sub get_active_symbols {

#  my $qry = 'SELECT symbol, exchange, SUM(number) AS number FROM '. $TABLE .' WHERE ttype=1 GROUP BY symbol HAVING number>0';
  my $qry = 'SELECT t.symbol, t.exchange, SUM(t.number) AS number FROM '
  	    ._table().' t,'. _table().' tr WHERE t.ttype=1 '
	    .' AND t.symbol=tr.symbol GROUP BY t.symbol,t.exchange';

  my $rows = Stocks::DB::select ( sql => $qry );

  my %symbol = map{$_->{symbol} => $_} @$rows;

  return \%symbol

} # get_active


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

# Is this transaction in a DB?
# ARG: none
# RET: bool

sub found {
  my $self = shift;
  my $where;

  return unless $self->id; # || ($self->portid && $self->symbol && $self->date);

  if ( $self->id() ) {
     $where = 'id='.$self->id();
#  } else {
#     $where = "symbol='" .$self->symbol. "' AND date='". $self->date. "' AND portid=" . $self->portid;
  }

  my $id = Stocks::DB::select (table => _table(),
  			       fields => [qw(id)],
			       where => $where,
			       returns => 'scalar'
			      );

 $self->id ($id) if $id;

 return $id;
} # found

# Delete all transactions for given portfolio
# Class method
# ARG: portid => id

sub delete_all {
  my %arg = @_;
  my $portid = $arg{portid};

  croak "'portid' is required" unless $portid;
  
  my $id = Stocks::DB::delete ( table => _table, 
  				 field => 'portid', 
				 value => $portid
			        );
} #delete_all

# Return total number of rows in a table
# Class method
# ARG: none 
# EFFECTS: none
# RET: number of records in DB

sub getCount {

  return _get_count ( table => _table());
}


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
 
Stocks::TransactionHistory -- Stocks Transaction Interface 
 
=head1 SYNOPSIS

use Stocks::Transaction;

my $t = Stocks::Transaction::Get (id => '16');
$t->dump;

$t = Stocks::Transaction->new(
  				 ttype  => 1, 
				 number =>100, 
				 price  =>99.98, 
				 portid => 2, 
				 symbol =>'ABX',
                                 exchange => 'TSX', 
				 fees   => 9.99,
				 date   => '2008-08-01 12:00:05',
				 amount => 99.98*100-9.99,
				 descr  => 'testing'
   				 );

my $saved_rec_id = $t->save ();
my $deleted_rec_id = $t->delete;

=head1 INTERFACE

=head2 constructor

=head2 Save

Saves transaction into DB

=head2 dbGetId

=head2 dbValues

=head2 Delete

==head2 Save 

==Dump

==_insert

==_update

=head1 AUTHOR

Dimitri Ostapenko (d@perlnow.com)
 
=cut
