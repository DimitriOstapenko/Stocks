# Broker table interface module 
#
# by Dmitri Ostapenko, d@perlnow.com   

package Stocks::Broker;

$VERSION = 1.00;

use strict;
use Moose;

with qw(Stocks::Base);

use Stocks::Types qw( All );
use Stocks::DB;
use List::Util qw(max);
use Carp;

#use Smart::Comments;
#use Data::Dumper;

#                                   Table "public.broker"
#    Column     |         Type          |                      Modifiers                      
#---------------+-----------------------+-----------------------------------------------------
# id            | integer               | not null default nextval('broker_id_seq'::regclass)
# name          | character varying(80) | not null
# pricemodel    | pricemodeltype        | not null
# ca_commission | double precision      | not null
# tag           | character varying(12) | not null default ''::character varying
# us_commission | double precision      | not null default 0
# Indexes:
#    "pkey_broker_id" PRIMARY KEY, btree (id)


#
# Objects of this class will have following attributes:

	has 'id' => (is => 'rw', isa => 'PosInt' );                                 # id
	has 'name' => (is => 'ro', isa => 'Str');                                   # Brokerage name 
	has 'tag' => (is => 'ro', isa => 'Str');                                    # Short name 
	has 'pricemodel' => (is => 'ro', isa => 'PriceModelType');                  # see Types.pm 
	has 'ca_commission' => (is => 'ro', isa=> 'Maybe[PosFloat]', default=>0.0); # CA commission 
	has 'us_commission' => (is => 'ro', isa=> 'Maybe[PosFloat]', default=>0.0); # US commission


__PACKAGE__->meta->make_immutable;
no Moose;

sub _table { 'broker' }

# Custom initializer
# ARG : class, %fields
#
sub _BUILDARGS {    #!!!!!!!!!!!
   my ($class, %arg) = @_;

   croak "'name' is required parameter" unless $arg{name};
   croak "'tag' is required parameter" unless $arg{tag};
   croak "'pricemodel' is required parameter" unless $arg{pricemodel};
   croak "'ca_commission' is required parameter" unless $arg{"ca_commission"};
   croak "'us_commission' is required parameter" unless $arg{"us_commission"};
   croak "'pricemodel' only accepts 'share' or 'trade' as values" unless ($arg{pricemodel} eq 'share' or $arg{pricemodel} eq 'trade');

   return $class->SUPER::BUILDARGS(%arg)
} # BUILDARGS

sub BUILD {
  my $self = shift;

  my $attr  = $self->get_attributes();
  my $defs =  $self->get_defaults();

} # BUILD

# get broker by id or tag 
# ARG: id || tag
# RET: obj

sub get {
   my (%arg) = @_;
   my $where;

   croak 'id or tag is required' unless ($arg{id} || $arg{tag});

   if ( $arg{id} ) {
      $where .= 'id='.$arg{id}
   } else {
      $where .= "LOWER(tag)=LOWER('".$arg{tag}."')"
   }

   my $row = Stocks::DB::select (table => _table,
     			         where => $where,
		                 limit => 1
   			        );

   return  __PACKAGE__->new ( $row ) if ref $row;
   return
}

# get all brokers from table
# ARG: none
# hash id => name

sub getAll {
    my $rows = Stocks::DB::select ( table => _table(),
    				    fields => [qw(id name)]
		   	           );
    
    return {map { $_->{id}, $_->{name}} @$rows}
} # getAll

# get fee for given number of shares
# obj method
# ARG: shares (number of shares)
#      market : US | CA
# RET: scalar

sub getFee {
    my ($self, %arg) = @_;
     
    croak "'shares' and 'market' are required parameters" unless ($arg{shares} && $arg{market});
    
    if (uc $arg{market} eq 'US') {
       if ($self->pricemodel() eq 'share') {
          return max(1,$arg{shares} * $self->us_commission())    # no less than $1
       } elsif ($self->pricemodel() eq 'trade') {
          return $self->us_commission()
       } 
    } elsif (uc $arg{market} eq 'CA') {
       if ($self->pricemodel() eq 'share') {
          return $arg{shares} * $self->ca_commission()
       } elsif ($self->pricemodel() eq 'trade') {
          return $self->ca_commission()
       }
    } else {
       croak "unrecognized market '".$arg{market}."'";
    }

} # getFee

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

# Is there record in a DB for this broker?
# obj method
# ARG: none
# RET: bool

sub found {
  my $self = shift;
  my $where = 'id='.$self->id();

  croak "id or tag is required" unless $self->id() || $self->tag();

  if ( $self->id() ) {
     $where = 'id='.$self->id();
  } else {
     $where = "tag='" .$self->tag. "'";
  }

  my $id = Stocks::DB::select (table => _table(),
  			       fields => [qw(id)],
			       where => $where,
			       returns => 'scalar'
			      );

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

1;


__END__
 
=head1 NAME
 
Stocks::Broker -- Stocks Broker Interface 
 
=head1 SYNOPSIS

my $broker = Stocks::Broker->new ( name => 'Scotia iTrade', tag =>'iTrade', pricemodel =>'trade', ca_commission => '9.99' );

$broker->get;
$broker->save;
$broker->delete;

=head1 INTERFACE

=head2 constructor

=head2 Save

Saves portfolio into DB

=head2 dbValues

=head2 idFound

=head1 AUTHOR

Dimitri Ostapenko (d@perlnow.com)
 
=cut
