#%% DailyTotals interface functions using Moose
#
# by Dmitri Ostapenko, d@perlnow.com   

package Stocks::DailyTotals;

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

#+--------+--------------+------+-----+------------+----------------+
#| Field  | Type         | Null | Key | Default    | Extra          |
#+--------+--------------+------+-----+------------+----------------+
#| id     | int(11)      | NO   | PRI | NULL       | auto_increment | 
#| portid | int(11)      | NO   |     | NULL       |                | 
#| date   | date         | NO   | MUL | 0000-00-00 |                | 
#| equity | double(16,5) | NO   |     | NULL       |                | 
#| cash   | double(16,5) | NO   |     | 0.00000    |                | 
#| descr  | varchar(120) | YES  |     | NULL       |                | 
#+--------+--------------+------+-----+------------+----------------+

#
# Objects of this class will have following attributes:

    has 'id' => (is => 'rw', isa => 'PosInt');                            # DailyTotals id
    has 'portid' => (is => 'ro', isa => 'PosInt',required => 1);          # Portfolio id
    has 'date' => (is => 'ro', isa => 'Date', required => 1);  	  	  # Date 
    has 'equity' => (is => 'rw', isa => 'Maybe[Num]', default => undef);  # Total equity for this port
    has 'cash' => (is => 'rw', isa => 'Maybe[Num]', default => undef);    # Cash pos in this port
    has 'descr' => (is => 'ro', isa => 'Maybe[Str]', default => '');      # Comment

__PACKAGE__->meta->make_immutable;
no Moose;

sub _table { 'daily_totals' }

# Get row with given id
# Class method
# ARG: id
# RET: object

sub get {
  my (%arg) = @_;
  my $id = $arg{id};

  croak "'id' is required" unless $id;

  my $row = Stocks::DB::select( table => _table(),
  				where => 'id='.$id,
				limit => 1
			       );

  return __PACKAGE__->new( $row );
} #get

# Get totals history for this portfolio
# class method
# ARG: portid : portfolio id (req)
#      sdate : start date (opt)
#      edate : end date (opt)
# RET: arrayref

sub getPortTotals {
   my %arg = @_;
   my $portid = $arg{portid};
   my $sdate = $arg{sdate};
   my $edate = $arg{edate};
   my $and = '';

   croak "'portid' is required" unless $portid;
   $and .= " AND date >= '$sdate' " if $sdate;
   $and .= " AND date < '$edate' " if $edate;

   my $rows = Stocks::DB::select (table => _table(),
   				  fields => [("to_char(date, 'Mon')", 'cash+equity AS value', 'date')], 
				  where => "portid=$portid $and",
				  order_by => 'date',
				  returns => 'array'
				  );

   return $rows
} # getPortTotals

# Get totals history for this user
# class method
# ARG: username : username (req)
#      sdate : start date (opt)
#      edate : end date (opt)
# RET: arrayref : all portfolios grand totals grouped by date

sub getUserTotals {
   my %arg = @_;
   my $username = $arg{username};
   my $sdate = $arg{sdate};
   my $edate = $arg{edate};
   my $and = '';

   croak "'username' is required" unless $username;
   $and .= " AND date >= '$sdate' " if $sdate;
   $and .= " AND date < '$edate' " if $edate;

   my $qry = "SELECT to_char(date, 'Mon DD'), SUM(cash+equity) AS value, date FROM "
   	    . _table()." t, portfolio p, stuser u WHERE t.portid=p.id AND p.active AND p.username=u.username AND p.username=? "
	    . $and . ' GROUP BY date ORDER BY date ';  

   my $rows = Stocks::DB::select ( sql => $qry,
  			 	   values => [($username)],
				   returns => 'array'
				 );

   return $rows
} # getUserTotals

# get prev trading day grand total for this user across all portfolios
# ARG: username
# RET: scalar

sub getPrevTtlVal {
  my %arg = @_;
  my $username = $arg{username};

  croak "'username' is required" unless $username;
   
  my $qry = "SELECT SUM(cash+equity) AS value FROM "._table()
   	   ." t, portfolio p, stuser u WHERE t.portid=p.id "
	   ." AND p.username=u.username AND p.username=? AND p.active"
	   ." AND date < current_date GROUP BY date ORDER by date DESC LIMIT 1";
	   
   my $ttlval = Stocks::DB::select ( sql => $qry,
  		  	   	     values => [($username)],
				     returns => 'scalar'
				   );

   return $ttlval
}

# Get total max value and date across portfolios (same date for all)
# ARG: none
# RET: hash 'date' => 'value';

sub getAllMax {
   my %arg = @_;

   return _getMinMax ( what => 'max', username => $arg{username} );
} # getAllMax

# Get total min value and date across portfolios (same date for all)
# ARG: none
# RET: hash 'date' => 'value';

sub getAllMin {
  my %arg = @_;

  return _getMinMax ( what => 'min', username => $arg{username} );
} # getAllMin

# Get total max value and date across portfolios (same date for all)
# ARG: username : str
#      year : THIS | LAST | ALL
# RET: hash 'date' => 'value';

sub getYrMax {
   my %arg = @_;

   return _getMinMax ( what => 'max', username => $arg{username}, year => $arg{year});
} # getYrMax

# Get total min value and date across portfolios (same date for all)
# ARG: username : str
#      year : THIS | LAST | ALL
# RET: hash 'date' => 'value';

sub getYrMin {
  my %arg = @_;

  return _getMinMax ( what => 'min', username => $arg{username}, year => $arg{year} );
} # getAllMin

# Get total (equity+cash) min/max value and date across portfolios for this user
# private method
# ARG: what => 'min'/'max'
#      username => str
#      year => str : ALL | THIS | LAST  (opt, ALL by def)
# RET: hashref

sub _getMinMax {
  my %arg = @_;
  my $order = ($arg{what} eq 'max') ? 'DESC': 'ASC';
  my $username = $arg{username} ;
  my $year = $arg{year} || 'ALL';
  my $thisyear = (localtime())[5] + 1900;
  my $yr = undef;

  croak "'username' is required " unless $username;
  croak "'year' must be 'THIS','LAST' or 'ALL' " 
         unless $year eq 'THIS' or $year eq 'LAST' or $year eq 'ALL';

  my $where = ' WHERE p.active AND d.portid=p.id AND p.username=? ';

  if ($year eq 'THIS' ) {
    $yr = $thisyear;
  } elsif ($year eq 'LAST') {
    $yr = $thisyear - 1;
  }
  $where .= " AND date >= '$yr-01-01' AND date <= '$yr-12-31'" if $yr;

  my $qry = "SELECT to_char(date,'Mon DD') AS date, SUM(equity+cash) AS value FROM "
  	    ._table().' d, portfolio p '
	    . $where
	    .' GROUP BY date ORDER BY value '. $order;

  my $row = Stocks::DB::select ( sql => $qry,
  			 	 values => [($username)],
  				 limit => 1
				);
  
  return $row;
} # _getMinMax

# Get latest portfolio totals
# Class method
# ARG: portid => 'num'
# RET: obj 

sub getLast {
  my (%arg) = @_;
  my $portid = $arg{portid};
  my $year = $arg{year};
  my $and = '';
  $and = " AND date < '" . ($year+1) . "-01-01'" if $year;

  croak "portid is required" unless $portid;

  my $qry = 'SELECT * FROM '. _table(). ' WHERE portid=? '. $and.' ORDER BY date DESC';
  my $row = Stocks::DB::select( sql => $qry, 
  				values => [($portid)],
				limit => 1
			       );

  return unless ref $row;
  return __PACKAGE__->new ($row); 

} #getLast

# Get prev trading day's portfolio totals
# Class method
# ARG: portid => 'num'
# RET: obj 

sub getPrev {
  my (%arg) = @_;
  my $portid = $arg{portid};

  croak "portid is required" unless $portid;

  my $qry = 'SELECT * FROM '. _table(). ' WHERE portid=? AND date < date(now()) ORDER BY date DESC';
  my $row = Stocks::DB::select( sql => $qry, 
  				values => [($portid)],
				limit => 1
			       );

  return unless ref $row;
  return __PACKAGE__->new ($row); 

} #getPrev

# Get totals for given month/portfolio
# Class method
# ARG: portid => 'num'
#      month => 'num' (opt) current month by def
#      year  => 'num' (opt) current year by def
# RET: obj 

sub getMonthTotals {
  my (%arg) = @_;
  my $portid = $arg{portid};
#  my $thisyear = Stocks::Utils::thisyr;  # (localtime())[5] + 1900;
  my ($year) = $arg{year} || Stocks::Utils::thisyr;
  my $mon = $arg{month} || Stocks::Utils::thismon;
  my $nextmon = $mon < 12 ? $mon + 1 : 1;

  croak "portid is required" unless $portid;

  my $where =  "portid=$portid AND date>= '$year-$mon-01' ";

  $year++ if $mon > 11;
  $where .= "AND date < '$year-$nextmon-01'";

  my $row = Stocks::DB::select( table => _table(),
  		                where => $where,
				order_by => 'date DESC',
				limit => 1
			       );

  $row = { portid => $portid, date=> $year.'-'.$mon.'-'.'01', descr=>'no data!' } unless ref $row and $row->{id};
  return __PACKAGE__->new ($row);

} #getMonthTotals

# Get totals for given quarter/portfolio
# Class method
# ARG: portid => 'num'
#      qtr   => 'num' (opt) current qtr by def
#      year  => 'num' (opt) current year by def
# RET: obj 

sub getQtrTotals {
  my (%arg) = @_;
  my $portid = $arg{portid};
  my ($year) = $arg{year} || Stocks::Utils::thisyr;
  my $qtr = $arg{qtr} || Stocks::Utils::thisqtr;
  my $nextqtr = $qtr < 4 ? $qtr + 1 : 1;
  my @QtrMon = (0,1,4,7,10);
  my $smon = $QtrMon[$qtr];
  my $nextQsmon = $QtrMon[$nextqtr];

  croak "portid is required" unless $portid;

  my $where = "portid=$portid AND date>= '$year-$smon-01' ";

  $year++ if $qtr > 3;
  $where .= "AND date < '$year-$nextQsmon-01'";

  my $row = Stocks::DB::select( table => _table(),
  		                where => $where,
				order_by => 'date DESC',
				limit => 1
			       );

  $row = { portid => $portid, date=> $year.'-'.$nextQsmon.'-'.'01', descr=>'no data!' } unless ref $row and $row->{id};
  return __PACKAGE__->new ($row);

} #getQtrTotals


# Get daily totals for this month
# ARG : portid
#       year [2009...] (opt) cur yr by def
#       month [1..12] (opt) cur mon by def
# RET : array

sub getMonth {
  my (%arg) = @_;
  my $portid = $arg{portid};
  my ($year) = $arg{year} || (localtime())[5] + 1900;
  my $mon = $arg{month} || (localtime)[4] + 1;
  my $nextmon = $mon< 12 ? $mon + 1 : 1;

  croak "portid is required" unless $portid;

  my $where =  "portid=$portid AND date>= '$year-$mon-01' ";
  $where .= "AND date < '$year-$nextmon-01'" unless $mon > 11;

  my $rows = Stocks::DB::select( table => _table(),
  		                 where => $where,
				 order_by => 'date'
			        );

  return $rows

} # getMonth

# Get max row based on equity for given portfolio
# ARG : portid => num
# RET: obj

sub getMax {
   my (%arg) = @_;

   croak "portid is required" unless $arg{portid};

   $arg{what} = 'MAX';
   return _getPortMinMax( %arg );

} # getMax

# Get min row based on equity for given portfolio
# ARG : portid => num
# RET: obj

sub getMin {
   my (%arg) = @_;

   croak "portid is required" unless $arg{portid};

   $arg{what} = 'MIN';
   return _getPortMinMax( %arg );

} # getMin

# Get min/max row based on equity for given portfolio
# ARG: portid => num  (req) 
# RET: obj

sub _getPortMinMax {
   my (%arg) = @_;
   my $portid = $arg{portid};
   my $what = uc $arg{what};
   my %ord = ('MIN' => 'ASC', 'MAX' => 'DESC');

   croak "'what' parameter should be 'min' or 'max'" unless ($what eq 'MIN' || $what eq 'MAX');
   croak "'portid' parameter is required " unless $portid;

   my $qry = 'SELECT * FROM '._table().' WHERE portid=? ORDER BY (equity+cash) '.$ord{$what};

   my $row = Stocks::DB::select( sql => $qry, 
  				  values => [($portid)],
				  limit => 1
			       );
   
   return unless ref $row;
   return __PACKAGE__->new( $row );
} # getMax


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

  return unless $self->id || ($self->portid && $self->date);

  if ( $self->id() ) {
     $where = 'id='.$self->id();
  } else {
     $where = 'portid='.$self->portid." AND date='". $self->date. "'";
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
 
Stocks::DailyTotals -- Stocks DailyTotals Interface 
 
=head1 SYNOPSIS

my $tr = Stocks::DailyTotals->new ( portfolio => 1, type => 1, symbol => 'ABX', date => '2008-12-07 10:44:45',
                                    exchange => 'CDN', number => 100, price => 50.10);

$tr->Save();

$tr->Get

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
