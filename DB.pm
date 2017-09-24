# DB wrapper class; postgres version
#
# by Dmitri Ostapenko, d@perlnow.com

package Stocks::DB;

use strict;
use version; our $VERSION = qv('1.0.0');
use DBI;
use Carp;
use English qw( -no_match_vars );

use Stocks::Config qw($CONFIG);
use subs qw(_connect);

#use Smart::Comments;

use constant MAX_TRIES => 5;

# Execute a query with parameters
# ARGS: query string
# EFFECTS: connects to DB if not connected yet
# RET: statement handle 
#
sub query {
  my ($sql, @args, $sth) = @_;
  my $dbh = _connect();
 
# query sql : $sql
# query args: @args

  $sth = $dbh->prepare($sql) || croak  $dbh->errstr(). 'args: ', join',', @args;
  $sth->execute(@args) || croak  $dbh->errstr(). 'args: ', join',', @args;

  return $sth;
}             

# Execute an SQL statement without parameters
# ARGS: SQL query
# EFFECTS: connect to DB if not connected yet
# RET: statement handle

sub execute {
   my $sql = shift;

   my $dbh = _connect();

### execute sql : $sql

   return $dbh->do($sql) or croak $dbh->errstr;
}

# Top-level select; Figure out which sub to call depending on the type of argument
# ARG: str or hash
# Supports 2 call interfaces: string and hash (see _select_str_arg and _select_hash_arg)
# RET: scalar or arrayref of hashrefs/arrayrefs, depending on the context

sub select {
  my %arg = @_;
  $arg{sql} = $arg{qry} if $arg{qry};

  if ($arg{table}) {
     return _select_hash_arg ( %arg )
  } else {
     return _select_str_arg ( %arg );
  }

} #select

# Run "INSERT" query (PG-specific RETURNING id)
# ARGS: table  => 'table_name' (req)
#       keys   => \@keys       (req)
#       values => \@values     (req)
#  or   keyval => { (key => val,..) } (req)
# EFFECTS : connect to DB if not connected yet
#       Croak with appropriate error message if one of the required fields was not passed
# RET: last_insert_id
# 
sub insert {
    my %arg = @_;
    my $table =  $arg{table};
    my @keys = @{$arg{keys}} if $arg{keys} && (ref $arg{keys} eq 'ARRAY');
    my @values = @{$arg{values}} if $arg{values} && (ref $arg{values} eq 'ARRAY');
    my %keyval = %{$arg{keyval}} if $arg{keyval} && (ref $arg{keyval} eq 'HASH');
    my $pref = __PACKAGE__.': insert error: ';

    croak $pref." need 'table' parameter" unless $table;
    croak $pref." need 'keys' or 'keyval' parameter" unless @keys || %keyval;
    croak $pref." need 'values' or 'keyval' parameter" unless @values || %keyval;

    if ( %keyval ) {
       @keys = keys %keyval;
       @values = values %keyval;
    } 

    my $dbh = _connect();
    my $qry = "INSERT INTO $table (".(join',',@keys) .") VALUES('". (join"','", @values) . "') RETURNING id";

### insert qry: $qry

    my $sth = query ($qry); 
    my $rows =  $sth->fetch() if $sth;
    
    return $rows->[0] if ref $rows && $rows->[0];

} # insert


# Run "UPDATE" query 
# ARGS: table  => 'table_name' (req)
#       keys   => \@keys       (req)
#       values => \@values     (req)
#  or   keyval => { (key => val,..) } (req opt)
#  and  where  => ' id=12343212'      (req) 
# EFFECTS : connect to DB if not connected yet
#       Croak with appropriate error message if one of the required fields was not passed
# RET: updated_id
# 
sub update {
    my %arg = @_;
    my $table =  $arg{table};
    my @keys = @{$arg{keys}} if $arg{keys} && (ref $arg{keys} eq 'ARRAY');
    my @values = @{$arg{values}} if $arg{values} && (ref $arg{values} eq 'ARRAY');
    my %keyval = %{$arg{keyval}} if $arg{keyval} && (ref $arg{keyval} eq 'HASH');
    my $where = $arg{where};
    my $pref = __PACKAGE__.'::update error: ';

    croak $pref."need 'table' parameter" unless $table;
    croak $pref."need 'keys' or 'keyval' parameter" unless @keys || %keyval;
    croak $pref."need 'values' or 'keyval' parameter" unless @values || %keyval;
    croak $pref."need 'where' parameter" unless $where ;

    @keyval{@keys} = @values if @keys;

    my $dbh = _connect();

    my $qry = "UPDATE $table SET ". (join',', map{"$_='$keyval{$_}'"} keys %keyval) ." WHERE $where RETURNING id";

### update qry: $qry

    my $sth = query ($qry); 
    my $rows =  $sth->fetch() if $sth;
    
    return $rows->[0] if ref $rows && $rows->[0];

    return
} # update

# Delete 1 row with given unique id from given table
# ARGS: table  => $table, (req)
#       and either:
#       field  => delete based on value in this field   (req)
#	value  => field value (req)
#       or :
#       where  => where clause
# RET: id of the deleted row (if any) (field,value)
#      or number of rows ('where')

sub delete {
  my %arg = @_;
  my $pref = __PACKAGE__.'::delete error: ';
  my $qry = 'DELETE FROM ' . $arg{table} . ' WHERE ';

  croak $pref."need 'table' parameter" unless $arg{table};
  croak $pref."need 'field' or 'where' parameter" unless $arg{field} || $arg{where};
  croak $pref."need 'value' or 'where' parameter" unless $arg{value} || $arg{where};

  if ( $arg{field} ) { 
     $qry .= $arg{field}.'=? RETURNING id';
     my $sth = query ($qry, $arg{value}); 
     my $row =  $sth->fetchrow_arrayref() if $sth;
     return $row->[0] if ref $row && $row->[0];
  } else {
     $qry .= $arg{where}.' RETURNING id';
     my $sth = query ( $qry ); 
     my $rows =  $sth->fetchall_arrayref() if $sth;
     return scalar @$rows if ref $rows
  }

} #delete


#_______________________________Private Methods___________________________

# Connect to database; reuse handle in mod_perl environment
# ARGS: none (connection parameters are set in %CONFIG hash)
# RET: DB handle
#
sub _connect {
    my $dbh;
    my $pref = __PACKAGE__.'_connect error: ';
    TRY:
    for my $try (1..MAX_TRIES) {
        eval {
            $dbh = DBI->connect($CONFIG->{db}{dsn}, $CONFIG->{db}{user}, $CONFIG->{db}{pass}, $CONFIG->{db}{options});
            last TRY;
        };
        croak($pref."Can't open connection to database (check Config.pm & network settings): ". $EVAL_ERROR ) if $try == MAX_TRIES;
        sleep (1);
    }

  return $dbh;
} # _connect


# Run "SELECT" query and return the result
# ARGS: sql     : query string
#       values  : array of values corresponding to placeholders in 'sql'
#       returns : 'array','hash','scalar' (opt) 'hash' is default
#       limit   : <num> number of rows to return; 
# EFFECTS: connect to DB if not connected yet
# RET: hashref/arrayref/scalar (def hashref) depending on 'returns' param
#      simple ref if limit=1
#
sub _select_str_arg {
  my %arg  = @_;
  my $rows;
  my $pref = __PACKAGE__.'::_select_str_arg error: ';
  my $sql = $arg{sql};
  my $limit = $arg{limit};
  my $returns = lc $arg{returns} if $arg{returns};
  $returns ||= 'hash';

  croak $pref."'sql' parameter is required" unless $sql;
  croak $pref.'SELECT queries only, sorry' unless $sql =~ /^\s*SELECT/i;

  my @values = ();
  if ( ref $arg{values} ) {
     croak $pref. " Arrayref is required in 'values'" unless ref $arg{values} eq 'ARRAY';
     @values = @{$arg{values}};
  }   

  my $dbh = _connect();
  my $sth = query ($sql, @values); 

  if ( $returns eq 'array' ) {
     $rows = $sth->fetchall_arrayref();
     $rows = $rows->[0] if (ref $rows and $arg{limit} == 1);
  } elsif ($returns eq 'scalar') {
     $rows = $sth->fetchrow_arrayref();
     return $rows->[0] if ref $rows;
  } else {
     $rows = $sth->fetchall_arrayref({});
     $rows = $rows->[0] if (ref $rows and $arg{limit} == 1);
  }

  return $rows

} # _select_str_arg

# Run "SELECT" query and return the result as array of hashrefs
# ARGS: table  : table name (req)
#       fields : arrayref : fields to select (opt) (def *)
# 	where  : where clause without word 'where' (opt)
#	group_by : GROUP BY clause (opt)
#	order_by : ORDER BY clause (opt)
#  	limit    : LIMIT <num> (opt)
#       offset   : OFFSET <num> (opt)
#       returns : 'array','hash','scalar' (opt) 'hash' is default
#
# EFFECTS: connect to DB if not connected yet.
# RET: hashref/arrayref/scalar (def hashref) depending on 'returns' param
#      simple ref if limit=1
#
sub _select_hash_arg {
  my %arg = @_;
  my $rows;
  my $pref = __PACKAGE__.'::_select_hash_arg error: ';

# arg : %arg

  croak $pref ."'table' parameter is required" unless defined $arg{table};
  if ( $arg{limit} ) {
     croak $pref . "'limit' parameter must be numeric" unless $arg{limit} =~ /^(\d+)$/;
  }
  if ( $arg{offset} ) {
     croak $pref . "'offset' parameter must be numeric" unless $arg{offset} =~ /^(\d+)$/;
  }
  
  my $table = $arg{table};
  my $fields = '*';

  if ( ref $arg{fields} ) {
     croak $pref. " Arrayref is required in 'fields'" unless ref $arg{fields} eq 'ARRAY';
     $fields = join',', @{$arg{fields}};
  }   

  my $where  = ' WHERE '.$arg{where} if $arg{where};
  my $group_by = ' GROUP BY '.$arg{group_by} if $arg{group_by};
  my $order_by = ' ORDER BY '.$arg{order_by} if $arg{order_by};
  my $limit = ' LIMIT '. $arg{limit} if ($arg{limit} && $arg{limit} >0);
  my $offset = ' OFFSET '. $arg{offset} if $arg{offset}; 
  my $returns  = lc $arg{returns} if $arg{returns};
  $returns ||= 'hash';

  my $dbh = _connect();
  my $sql = 'SELECT '. $fields . ' FROM '. $table . $where . $group_by . $order_by . $limit . $offset;

# _select_hash_arg sql : $sql

  my $sth = query ( $sql ); 

  if ( $returns eq 'array' ) {
     $rows = $sth->fetchall_arrayref();
     $rows = $rows->[0] if (ref $rows and $arg{limit} == 1);
  } elsif ($returns eq 'scalar') {
     $rows = $sth->fetchrow_arrayref();
     return $rows->[0] if ref $rows;
  } else {
     $rows = $sth->fetchall_arrayref({});
     $rows = $rows->[0] if (ref $rows and $arg{limit} == 1);
  }
  
  return $rows;

} # _select_hash_arg


1;

__END__

=head1 NAME

Stocks::DB - FN DB wrapper

=head1 VERSION

This documentation refers to Stocks::DB version 1.00

=head1 SYNOPSIS

use Stocks::DB;
use Carp;
use Data::Dumper;

my $TABLE = 'transaction';

$qry = "SELECT id, symbol, price FROM ". $TABLE. " WHERE portid=? ORDER BY date LIMIT ?";
my @vals = (1, 10);

eval {
      $rows = Stocks::DB::select (sql     => $qry, 
      				 returns => 'hash', 
				 values => \@vals 
				);
     } || croak  "DB.pm: Could not select record : \n". $EVAL_ERROR;

print 'select_str_arg : ', Dumper $rows;

my @fields = qw(id symbol price date);

eval {
        $rows = Stocks::DB::select ( table => $TABLE,
                                    fields => \@fields,
                                    where => "portid=1",
                                    order_by => 'date',
                                    limit => 5,
                                    returns => 'hash'
                                  );
     } || croak  "DB.pm: Could not select record : \n". $EVAL_ERROR;

print 'select_hash_arg : ', Dumper $rows;

@vals = qw(1 10);
$qry = "SELECT symbol,date FROM ". $TABLE. " WHERE portid=? LIMIT ?";

my $val;
eval {
     $val = Stocks::DB::select (sql => $qry,
			       values => \@vals,
     			       returns => 'scalar', 
			      );
     } || croak  "DB.pm: Could not select record : \n". $EVAL_ERROR;

print 'select_str_arg ret scalar : ', $val, "\n";

eval {
      $val = Stocks::DB::select (table => $TABLE,
      				fields => \('symbol,'date'),
				where => "id=10", 
      				returns => 'scalar', 
			       );
     } || croak  "DB.pm: Could not select record : \n". $EVAL_ERROR;

print 'select_hash_arg ret scalar : ', $val, "\n";

my $sql = 'SHOW TABLES';
my $sth = Stocks::DB::execute( $sql );

# use select to get DB results with one call:

$qry = "SELECT * FROM $TABLE WHERE id = ?";

my @args = (1);
my $rows = Stocks::DB::select ( $qry, @args );

# use Stocks::DB::insert if you know that record is not in DB
    
    my $lastid = Stocks::DB::insert ( table => $TABLE,
    				     keys => [qw(symbol date price)],
				     values => [('BCE', '2009-01-01 00:00:00', 29.99)],
				   );

   or: 

    my $lastid = Stocks::DB::insert ( table => $TABLE,
                              	     keyval => {(symbol => 'BCE',
					         date => '2009-01-01 00:00:00', 
				  	         price => 29.99,
					       )}
                                   );

   use Stocks::DB::update to update existing record (where clause is required)

   $id = Stocks::DB::update( table => $TABLE,
    			    keys => [qw(symbol date price)],
			    values => [('BCE', '2009-01-01 00:00:00', 29.99)],
                            where  => 'id=5'
                          );

   or

   $id = Stocks::DB::update ( table  => $TABLE
    			     keys => [qw(symbol date price)],
			     values => [('BCE', '2009-01-01 00:00:00', 29.99)],
                             where  => 'id=5',
			);
                    


=head1 DESCRIPTION

This module implements functions of DB interface. It is to be used by any module or
program that requires access to Database. This way all DB-related functionality is 
encapsulated in one place to make any subsequent modifications easier. 

This particular implementation is using Postgres-specific SQL features, such as 'RETURNING'

=head1 SUBROUTINES

=head2 query($sql,@args);

Calls _connect()  to make sure connection to DB is open.  Executes the query and returns a statement handle to the caller.
If the user uses DBI query placeholders (see DBI manpage) then these may be passed to the "query" via @args.

=head2 execute($sql);

Same as query, but this sub doesn't take any parameters other that SQL statement

=head2 select($sql, @args);

Calls "query" to execute sql query passed in "sql" param with values in "values" param.
Returns result in arrayref/hashref depending on 'returns' parameter.

=head2 $inserted_id = insert(table=>$tab_name, keys=>\@keys, values=>\@vals);

Class method. Insert record into table passed as a 'table' parameter. Keys and values are passed in
'keys' and 'values' parameters (arrayrefs); Alternatively, %keyval hashref can be used to pass both.

 ARGS: table  => 'table_name' (req)
       keys   => \@keys       (req)
       values => \@values     (req)
  or   keyval => { (key => val,..) } (req)


Returns id of inserted row in case of success. 

=head2 $updated_id = update(table=> $tab_name, keys => \@keys, values=> \@vals);

Class method. Update existing record in the table passed as a 'table' parameter. Keys and values are passed in
'keys' and 'values' parameters (arrayrefs); Alternatively, %keyval hashref can be used to pass both.
'where' parameter defines condition for which record(s) to update

 ARGS: table  => 'table_name' (req)
       keys   => \@keys       (req)
       values => \@values     (req opt1)
  or   keyval => { (key => val,..) } (req opt2)
  and  where  => ' id=12343212'      (req) 

Returns id of updated row in case of success.

=head2 $deleted_id = delete (table=> $tab_name, id => 55);

 Delete record with given id from table.

 ARGS: table => $table, (req)
       id    => $id     (req)
 or    where => 'userid=999' (req)

 Returns id of deleted record in case of success

=head2 _connect();

Private static method.
Used internally to open connection to Database. DB handles are cached using Apache::DBI.
Data Set Name as well as auth info comes from "Stocks::Config" hash "$CONFIG";
Several attempts with short sleep in between are made to connect to DB (MAX_TRIES
constant determines the maximum).

Croaks with appropriate error if connection was not made

=head2 _select_str_arg

Private static method called from "select"
This is 1-st option to execute "SELECT" queries as far as passed arguments.
It requires 3 parameters described below.

 ARGS: sql     : query string
       values  : array of values corresponding to placeholders in 'sql'
       returns : array of 'array','hash','scalar' (opt) 'hash' is default

Returns either arrayref of arrayrefs, arrayref of hashrefs or simple value

=head2 _select_hash_arg

Private static method called from "select"
This is 2-nd option to execute "SELECT" queries as far as passed arguments.
It accepts parameters described below. Only 'table' parameter is required.

 ARGS: table    : table name (req)
       fields   : fields to select (opt) (def *)
       where    : where clause without word 'where' (opt)
       group_by : GROUP BY clause (opt)
       order_by : ORDER BY clause (opt)
       limit    : LIMIT <num> (opt)
       offset   : OFFSET <num> (opt)
       returns  : 'array','hash','scalar' (opt) 'hash' is default


Returns either arrayref of arrayrefs, arrayref of hashrefs or simple value

=head1 DIAGNOSTICS

  "need 'table' parameter" 
  "need 'keys' or 'keyval' parameter"
  "need 'values' or 'keyval' parameter" 
  "need 'table' parameter"
  "need 'keys' or 'keyval' parameter"
  "need 'values' or 'keyval' parameter"
  "need 'where' parameter"
  "need 'table' parameter" 
  "need 'id' parameter"
  "Can't open connection to database (check Config.pm & network settings): ". $EVAL_ERROR 
  "'sql' parameter is requited"
  "SELECT queries only, sorry'
  " Arrayref is required in 'values'"
  "'table' parameter is required"
  "'limit' parameter must be numeric"
  "'offset' parameter must be numeric"
  " Arrayref is required in 'fields'"

  dbi errors 

Note to developers:

  To suppress errors/get finer control on displaying errors,  set 
      ShowErrorStatement => 0, 
      RaiseError => 0, 
      PrintError => 0, 
  and wrap calls to Stocks::DB methods into eval statement
  This way caller can display custom message and/or display original error message by using $EVAL_ERROR


=head1 CONFIGURATION AND ENVIRONMENT

 uses Stocks::Config which defines $CONFIG hash;

  $CONFIG->{db}->{dsn}  : DSN name in the form "DBI:<dbiname>:<db_name>:<hostname>
  $CONFIG->{db}->{user} : DB username
  $CONFIG->{db}->{pass} : DB password 

 This package relies on the assumption that DB table hasunique  primary key 'id' (serial).

=head1 DEPENDENCIES

   version: version control
   DBI    : Perl distribution
   Carp   : Perl distribution
   Smart::Comments : CPAN
   English : CPAN

   Config : Module distribution

=head1 INCOMPATIBILITIES

 - Only Postgres 8.1 and up is supported
 - Only tables with 'id' as primary key are supported in higher-level methods such as 'insert', 'update' and 'delete'

=head1 BUGS AND LIMITATIONS

 There are no known bugs in this module.
 Please report problems to Dmitri Ostapenko  (d@perlnow.com)

 Patches are welcome.

=head1 AUTHOR

Dmitri Ostapenko (<d@perlnow.com>)

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2009 Ostapenko Consulting Inc.  All rights reserved.

This module is free software; you can redistribute it and/or modify it under the same 
terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
