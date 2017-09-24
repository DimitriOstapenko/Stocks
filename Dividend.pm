#%% Dividend interface functions using Moose
#
# by Dmitri Ostapenko, d@perlnow.com   

package Stocks::Dividend;

$VERSION = 1.32;

use strict;
use Moose; 

with qw(Stocks::Base);

use namespace::autoclean;
use Stocks::Types qw( All );
use Stocks::DB;
use Stocks::Utils;
use Carp;
use Smart::Comments;


#   Column   |         Type          |                       Modifiers                       
#------------+-----------------------+-------------------------------------------------------
# id         | integer               | not null default nextval('dividend_id_seq'::regclass)
# symbol     | character varying(11) | not null
# exchange   | exchangetype          | 
# value      | double precision      | 
# yield      | double precision      |  COMPUTED!!
# frequency  | smallint              | 
# exdiv_date | date                  | 
# pay_date   | date                  | 
#Indexes:
#    "unique_dividend_symbol_exchange" UNIQUE, btree (symbol, exchange)


#
# Objects of this class will have following attributes:

    has 'id' => (is => 'rw', isa => 'PosInt');                           # Dividend id
    has 'symbol' => (is => 'ro', isa => 'Str',required => 1);         	 # 
    has 'exchange' => (is => 'ro', isa => 'Exchange', default=>'TSX', required => 1);    	
    has 'value' => (is => 'rw', isa => 'Maybe[Num]', default => undef);  # Dollar value/share/year 
    has 'frequency' => (is => 'rw', isa => 'Maybe[PosInt]', default => undef);  # Times/year
    has 'exdiv_date' => (is => 'ro', isa => 'Maybe[Date]', default => undef);      # Ex dividend date
    has 'pay_date' => (is => 'ro', isa => 'Maybe[Date]', default => undef);      	# Pay Date

__PACKAGE__->meta->make_immutable;
no Moose;

sub _table { 'dividend' }

# Get row with given id
# Class method
# ARG: id | symbol, [exchange]
# RET: object

sub get {
  my (%arg) = @_;
  my $id = $arg{id};
  my $symbol = $arg{symbol};
  my $exch = $arg{exchange} || 'TSX';

  croak "id or symbol is required" unless $id || $symbol;

  my $where = "exchange='$exch' AND ";

   if ( $id ) {
      $where .= 'id='.$id
   } else {
      $where .= "symbol='$symbol'"
   }

  my $row = Stocks::DB::select( table => _table(),
  				where => $where,
				limit => 1
			       );

  return __PACKAGE__->new( $row );
} #get


sub getAll {
  my $rows  = Stocks::DB::select ( table => _table(),
				  order_by => 'symbol',
				 );

#  my @divs = map {__PACKAGE__->new( $_ )} @$rows if ref $rows; 

  return $rows
}


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

  return unless $self->id || ($self->symbol && $self->exchange);

  if ( $self->id() ) {
     $where = 'id='.$self->id();
  } else {
     $where = "symbol='".$self->symbol."' AND exchange='".$self->exchange."'"; 
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
 
Stocks::Dividend -- Stocks Dividend Interface 
 
=head1 SYNOPSIS

my $tr = Stocks::Dividend->new ( symbol => 'ABX', exchange => 'TSX', 
				 value => 0.46, yield => 1.65,
				 exdiv_date => '2011-12-07',
				 pay_date => '2012-01-07',
                               ); 

$tr->Save();

$tr->get

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
