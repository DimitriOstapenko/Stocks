# Stocks Transaction class using Moose 
# Maps to transaction table 
#
# by Dmitri Ostapenko, d@perlnow.com   

package Stocks::Transaction;

$VERSION = 1.23;

use strict;
use Moose; 

with qw(Stocks::Base);

use Stocks::Types qw( All );
use Stocks::DB;
use Carp;
#use Smart::Comments;
use namespace::autoclean;
use feature 'switch';


#+-----------+-------------------------------------+------+-----+---------------------+----------------+
#| Field     | Type                                | Null | Key | Default             | Extra          |
#+-----------+-------------------------------------+------+-----+---------------------+----------------+
#| id        | int(11)                             | NO   | PRI | NULL                | auto_increment | 
#| portid    | int(11)                             | NO   |     | NULL                |                | 
#| ttype     | int(2)                              | NO   |     | NULL                |                | 
#| ttype_str | varchar(80)                         | YES  |     | NULL                |                | 
#| date      | datetime                            | NO   |     | 0000-00-00 00:00:00 |                | 
#| setl_date | datetime                            | NO   |     | 0000-00-00 00:00:00 |                | 
#| symbol    | varchar(11)                         | NO   | MUL |                     |                | 
#| exchange  | enum('TSX','NYSE','AMEX','NASD','') | NO   |     |                     |                | 
#| price     | double(16,5)                        | NO   |     | NULL                |                | 
#| number    | double(16,5)                        | NO   |     | 0.00000             |                | 
#| fx_rate   | double(16,5)                        | NO   |     | 1.00000             |                | 
#| fees      | double(16,5)                        | YES  |     | NULL                |                | 
#| equity    | double(20,5)                        | YES  |     | NULL                |                | 
#| cash      | double(16,5)                        | YES  |     | NULL                |                | 
#| ttlnumber | double(16,5)                        | YES  |     | NULL                |                | 
#| avgprice  | double(16,5)                        | YES  |     | NULL                |                | 
#| descr     | varchar(120)                        | YES  |     | NULL                |                | 
#| strike    | real                                | YES  |     | NULL
#| weight    | double(16,5)                        | YES  |     | NULL                |                | 
#+-----------+-------------------------------------+------+-----+---------------------+----------------+


#
# Objects of this class will have following attributes:

    has 'id' => (is => 'rw', isa => 'PosInt');                          # Transaction id
    has 'portid' => (is => 'ro', isa => 'PosInt',required=>1);          # Portfolio id
    has 'ttype' => (is => 'ro', isa => 'TType', required=>1);           # Transaction type (0:dep/wthd 1:buy/sell 2:div 3:int 4: cash tfr 5: pos tfr 6: fee 7:call opt; 8: put opt)
    has 'ttype_str' => (is => 'ro', isa => 'Maybe[Str]',default=>'');   # Transaction type descriptor 
    has 'date' => (is => 'ro', isa => 'DateTime_',required=>1);   	# Transaction date/time
    has 'setl_date' => (is => 'ro', isa => 'DateTime_');   		# Settlement date/time
    has 'symbol' => (is => 'ro', isa => 'Str', required=>1);            # Stock symbol or 'cash'
    has 'exchange' => (is => 'ro', isa => 'Exchange',default => 'TSX'); # Exchange of the stock        !!!!!!!!!!!!!!!!!!!!!!!!!
    has 'price' => (is => 'ro', isa => 'Num', required=>1);        # Price at wich stock was bought/sold, interest value
    has 'strike' => (is => 'ro', isa => 'PosFloat', default=>0);        # Strike price for options
    has 'number' => (is => 'ro', isa => 'Num', required=>1);            # Number of shares bought/sold +/-
    has 'fx_rate' => (is => 'ro', isa=>'PosFloat', default=> 1);        # Exchange rate if not in currency of the portfolio 
    has 'fees' => (is => 'ro', isa => 'Maybe[PosFloat]', default=>0);   # Transaction fees
    has 'equity' => (is => 'rw', isa => 'Maybe[Num]', default=>0);      # Equity in/out this transaction
    has 'cash' => (is => 'rw', isa => 'Maybe[Num]',default=>0);       	# Cash in/out this transaction 
    has 'ttlnumber' => (is => 'rw', isa => 'Maybe[Num]',default=>0);    # Running total of shares this transaction 
    has 'avgprice' => (is => 'rw', isa => 'Maybe[Num]',default=>0);     # Avg price for symbol at this transaction 
    has 'descr' => (is => 'rw', isa => 'Maybe[Str]', default=>'');      # Comment
    has 'weight' => (is => 'rw', isa => 'Maybe[Num]',default=>0);       # weight for GLD 


__PACKAGE__->meta->make_immutable;
no Moose;

sub _table { 'transaction' }

#sub BUILD {
#  my $self =  shift;

## transaction obj : $self

#}


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

} #get

# Get latest transaction of the given type in given portfolio
# Class method
# ARG: portid => 'num'
#      ttype => 'num'
# RET: transaction object

sub getLatest {
  my (%arg) = @_;
  my $portid = $arg{portid};
  my $ttype =  $arg{ttype};

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

# Get oldest transaction of the given type in this portfolio
# Class method
# ARG: portid => 'num'
#      ttype => 'num'
# RET: transaction object

sub getOldest {
  my (%arg) = @_;
  my $portid = $arg{portid};
  my $ttype =  $arg{ttype};

  croak "'portid' is required" unless $portid;
  my $where = 'portid='.$portid;
  $where .= ' AND ttype='.$ttype if $ttype;

  my $row  = Stocks::DB::select ( table => _table(),
  				  where => $where,
				  order_by => 'date',
				  limit => 1
				 );

  return __PACKAGE__->new ( $row ) if $row; 

} #getLatest

# Get active unique symbols from portfolios (all by def)
# Class method
# ARG: portid (opt) 
# RET: hashref
sub get_active_symbols {
  my (%arg) = @_;
  my $and = '';
  $and = ' AND portid='.$arg{portid} if $arg{portid};

  my $qry =  'SELECT symbol, exchange, SUM(number) AS number FROM '
  	    . _table().' WHERE ttype=1 '.$and.' GROUP BY symbol,exchange HAVING SUM(number)>0';
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

# Is record for this user in a DB?
# ARG: none
# RET: bool

sub found {
  my $self = shift;
  my $where;

  return unless $self->id || ($self->portid && $self->symbol && $self->ttype && $self->date);

  if ( $self->id() ) {
     $where = 'id='.$self->id();
  } else {
     $where = 'portid=' .$self->portid. " AND symbol='" .$self->symbol. "' AND date='". $self->date. "' AND ttype=".$self->ttype;
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

# calculate fees for given date range
# Class method
# ARG: portid, sdate, edate
# RET: scalar

sub getFees {
    my %arg = @_;
    my $portid = $arg{portid};
    my $sdate = $arg{sdate};
    my $edate = $arg{edate};

    croak "'sdate' is required" unless $sdate;
     
    my $where =  "portid=$portid AND ttype=1 AND date>='$sdate' ";
    $where .= " AND date < '$edate'" if $edate;

    my $fees = Stocks::DB::select ( table => _table,
    				    fields => [('SUM(fees)')],
    				    where => $where,
     				    returns => 'scalar'
    				   ); 

    return $fees
} # getFees


# Get sum of fees for each symbol traded in given timeframe
# Class method
# ARG: portid, sdate, edate
# RET: hashref

sub getFeesBySymbol {
    my %arg = @_;
    my $portid = $arg{portid};
    my $sdate = $arg{sdate};
    my $edate = $arg{edate};

    croak "'sdate' is required" unless $sdate;
     
    my $where =  "portid=$portid AND ttype=1 AND date>='$sdate' AND fees>0";
    $where .= " AND date < '$edate'" if $edate;

    my $fees = Stocks::DB::select ( table => _table,
    				    fields => [qw(symbol SUM(fees) count(*))],
    				    where => $where,
				    group_by => 'symbol'
				  );
    return $fees
   
}


# Get non-transaction fees for given date range
# Class method
# ARG: portid, sdate, edate
# RET: scalar

sub getOtherFees {
    my %arg = @_;
    my $portid = $arg{portid};
    my $sdate = $arg{sdate};
    my $edate = $arg{edate};

    croak "'sdate' is required" unless $sdate;
     
    my $where =  "portid=$portid AND ttype=6 AND date>='$sdate' ";
    $where .= " AND date < '$edate'" if $edate;

    my $fees = Stocks::DB::select ( table => _table,
    				    fields => [('SUM(fees)')],
    				    where => $where,
     				    returns => 'scalar'
    				   ); 

    return $fees
} # getOtherFees

# calculate transfers for given date range
# Class method
# ARG: portid, sdate, edate
# RET: scalar

sub getTransfers {
    my %arg = @_;
    my $portid = $arg{portid};
    my $sdate = $arg{sdate};
    my $edate = $arg{edate};
    my $type  = $arg{type};

    croak "'sdate' is required" unless $sdate;
    croak "'type' is required" unless $type;
     
    my $where =  "portid=$portid AND date>='$sdate' ";
    $where .= " AND date < '$edate'" if $edate;
    $where .=  lc $type eq 'pos' ? ' AND ttype = 5' : ' AND ttype = 4';

    my $trfrs = Stocks::DB::select ( table => _table,
    				     fields => [('SUM(equity)')],
    				     where => $where,
     				     returns => 'scalar'
    				   ); 

    return $trfrs
} # getTransfers


# Get list of transfers in given timeframe ordered by date
# Class method
# ARG: portid, sdate, edate
# RET: hashref

sub getTransfersBySymbol {
    my %arg = @_;
    my $portid = $arg{portid};
    my $sdate = $arg{sdate};
    my $edate = $arg{edate};

    croak "'sdate' is required" unless $sdate;
     
    my $where =  "portid=$portid AND (ttype=5 OR ttype=4) AND date>='$sdate' ";
    $where .= " AND date < '$edate'" if $edate;

    my $trfrs = Stocks::DB::select ( table => _table,
    				    fields => [qw(symbol price number equity date fx_rate descr)],
    				    where => $where,
				    order_by => 'date DESC',
				  );
    return $trfrs
   
} # getTransfersBySymbol

# calculate dividends for given date range
# Class method
# ARG: portid, sdate, edate
# RET: scalar

sub getDividends {
    my %arg = @_;
    my $portid = $arg{portid};
    my $sdate = $arg{sdate};
    my $edate = $arg{edate};

    croak "'sdate' is required" unless $sdate;
     
    my $where =  "portid=$portid AND ttype=2 AND date>='$sdate' ";
    $where .= " AND date < '$edate'" if $edate;

    my $ttldiv = Stocks::DB::select ( table => _table,
    				      fields => [('SUM(cash)')],
    				      where => $where,
     				      returns => 'scalar'
    				     ); 

    return $ttldiv
} # getDividends

# calculate interest for given date range
# Class method
# ARG: portid, sdate, edate
# RET: scalar

sub getInterest {
    my %arg = @_;
    my $portid = $arg{portid};
    my $sdate = $arg{sdate};
    my $edate = $arg{edate};

    croak "'sdate' is required" unless $sdate;
     
    my $where =  "portid=$portid AND ttype=3 AND date>='$sdate' ";
    $where .= " AND date < '$edate'" if $edate;

    my $ttldiv = Stocks::DB::select ( table => _table,
    				      fields => [('SUM(cash)')],
    				      where => $where,
     				      returns => 'scalar'
    				     ); 

    return $ttldiv
} # getInterest

# Get trades for given date range/portfolio
# Class method
# ARG: portid, sdate, [edate], [symbol] (sym:exch)
# RET: arrayref of transaction objects 

sub getTrades {
    my %arg = @_;
    my $portid = $arg{portid};
    my $sdate = $arg{sdate};
    my $edate = $arg{edate};
    my $symbol = $arg{symbol};
    my $show_drip = $arg{'show_drip'} ||0;
    my @otr = (); 
    my $and ='';
    my ($sym, $exchange);

    croak "'sdate' is required" unless $sdate;
    
    given ( $show_drip ) {
          when ($show_drip == 1)   { $and = '' }                         # Including DRIP
          when ($show_drip == 2)   { $and = "AND descr ~* '^DPP*'" }     # DRIP only
	  default                  { $and = "AND descr !~* '^DPP*'" }    # Excluding DRIP
    }
      
    my $where =  "portid=$portid AND (ttype=1 or ttype=7 or ttype=8) AND date>='$sdate' ". $and;
    $where .= " AND date <= '$edate'" if $edate;
    
    if ($symbol) {
       ($sym,$exchange) = split(':', $symbol);
       $exchange ||= 'TSX';

       $where .= " AND symbol = '$sym' AND exchange = '$exchange' ";
    }

    my $rows = Stocks::DB::select ( table  => _table,
    		 		    fields => [('*')],
    				    where  => $where,
				    order_by  => 'date DESC',
    			          ); 
    foreach my $tr (@$rows) {
        push @otr, __PACKAGE__->new ( $tr );
    }

    return \@otr;
} # getTrades



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
 
Stocks::Transaction -- Stocks Transaction Interface 
 
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
				 equity => 99.98*100-9.99,
				 cash   => -(99.98*100-9.99),
				 descr  => 'testing'
   				 );

my $saved_rec_id = $t->save ();
my $deleted_rec_id = $t->delete;

=head1 INTERFACE

sub _table { 'transaction' }
sub get {
sub getLatest {
sub getOldest {
sub get_active_symbols {
sub find {
sub found {
sub delete_all {
sub getCount {
sub getFees {
sub getFeesBySymbol {
sub getTransfers {
sub getTransfersBySymbol {
sub getDividends {
sub getTrades {
sub _insert {
sub _update {

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
