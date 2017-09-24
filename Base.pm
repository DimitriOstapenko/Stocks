package Stocks::Base;
#
# Role with shared methods across all classes
#
# by Dmitri Ostapenko, d@perlnow.com

use Moose::Role;

# Require these methods to be implemented in consuming class:

requires qw(_table get find found _update _insert);

use Carp;
use Regexp::Common qw/list/;
use English;
use Data::Dumper;
#use Smart::Comments;
use Stocks::DB;
use namespace::autoclean;


#______________________Object Methods _______________________


# Save record to DB
# Object method
# Insert if id not in DB. Update otherwise.
# ARGS: none
# RET: id of new/updated record

sub save {
  my $self = shift;
  my $id;

### save obj: $self

# Is it existing record in DB?

  if ( $self->found ) {
     $id = $self->_update 
  } else {
     $id = $self->_insert;
     $self->id ($id) if $id;
  }

return $id;

} # save

# Delete db record associated with this object
# Object method
# ARG: none
# RET: row id
#
sub delete {
  my $self = shift;

  croak "Cannot delete record - 'id' is required" unless $self->id;

  my $id = Stocks::DB::delete ( table => $self->_table, 
  				 field => 'id', 
				 value => $self->id
			        );

  return $id

} # delete

# Get list of defined public attributes of this class (including base class)
# Object method
# ARG: none
# EFFECTS:
# RET: hashref attr => val
#
sub get_attributes {
    my $self = shift;
    my %keyval;

    my @attr = $self->meta->get_all_attributes;

    foreach my $attr ( @attr ) {
       my $name = $attr->name();
       next unless defined $self->$name;
       next if _is_private_attr($name);
       $keyval{$name} = $self->$name;
     }

    return \%keyval

} # get_attributes

# Get list of all public attributes of this class (including base class)
# Object method
# ARG: none
# EFFECTS:
# RET: hashref attr => val
#
sub get_all_attributes {
    my $self = shift;
    my %keyval;

    my @attr = $self->meta->get_all_attributes;

    foreach my $attr ( @attr ) {
       my $name = $attr->name();
       next if _is_private_attr($name);
       $keyval{$name} = $self->$name;
     }

    return \%keyval

} # get_attributes

# Get list of private attributes of this class (including base class)
# Private attributes don't have matching fields in DB
# Object method
# ARG: none
# EFFECTS:
# RET: hashref attr => val
#
sub get_private_attributes {
    my $self = shift;
    my %keyval;

    my @attr = $self->meta->get_all_attributes;

    foreach my $attr ( @attr ) {
       my $name = $attr->name();
       next unless defined $self->$name;
       next unless _is_private_attr($name);
       $keyval{$name} = $self->$name;
    }

    return \%keyval

} # get_private_attributes

# Get default values for this class (including base)
# Object method
# ARG: none
# RET: hashref attr_name => <def_value>

sub get_defaults {
   my $self = shift;
   my %default;

   my @attr = $self->meta->get_all_attributes;

   foreach my $attr ( @attr ) {
      $default{$attr->name()} = $attr->default() if defined $attr->default();
   }

   return \%default

} # get_defaults


# Object Dump
# Object method
# ARGS: none
# EFFECTS: prints dump of the passed object
# RET: none

sub dump {
  my $self = shift;
  my $meta = $self->meta;
  my $class = ref $self;

# not just this class but all in hierarchy
  my @attributes =  $meta->get_all_attributes;
  my @methods = $meta->get_method_list;

  print $class." : Object dump : \n";

#  foreach my $attr ( @attributes) {
#    print $attr->name(),"\n";
#  }

  print Dumper $self;

  print "<br>methods supported by this class: \n", join": ", @methods, "\n";

  return

} # dump



# ________________________Private Class Methods _______________________


# Find records matching given criteria
# Private Class method
# ARGS: table : DB table name (req)
#	field : field to search on (req)
#       value : value for the field (req)
#       type  : value type : Str, Num, Int
#       order_by : sort field (opt) 'field' by def
#       order : sort order (ASC/DESC) (opt) 'ASC' by def
#       returns : type of result returned : 'hash', 'array', 'scalar' 
# RET: hashref/arrayref/scalar
#
sub _find {
  my %arg =  @_;
  my $table =  $arg{table};
  my $field = $arg{field};
  my $type = ucfirst $arg{type} if $arg{type};
  my $value = $arg{value};
  my $order_by = $arg{'order_by'} || $field;
  my $order = uc $arg{order} if $arg{order};
  my $returns = $arg{returns} || 'hash';
  my $where;

  croak __PACKAGE__."'table' parameter id required" unless $table;
  croak __PACKAGE__."'value' parameter id required" unless $value;
  croak __PACKAGE__."'field' parameter id required" unless $field;
  if ( $type ) {
     croak __PACKAGE__."'type' parameter must be 'Str', 'Num' or 'Int' " 
  	   unless ($type eq 'Str' || $type eq 'Num' || $type eq 'Int');
  } else {
     $type = 'Str';
  }

  $order = 'ASC' unless (defined $order && $order =~ /^DESC/i);
  $order_by = $order_by . ' ' .$order;

# need cast for enum types:
  if ( $type eq 'Str' ) {
     $where = $field ."::text LIKE '" . $value . "%'"
  } elsif ( $type eq 'Int' ) {
     $where = "$field = $value"
  } else { 
     my $dev = $value / 10000;
     $where = "$field < $value + $dev  AND $field > $value - $dev";
  }

  my $rows = Stocks::DB::select ( table => $table,
  			          where => $where,
			       order_by => $order_by,
			        returns => $returns,
			          limit => $arg{limit}
			        );

  return $rows

} # _find


# Return total number of rows in a table
# Class method
# ARG: table => db table name
# EFFECTS: none
# RET: number of records in DB

sub _get_count {
  my %arg = @_;
  
  croak __PACKAGE__."'table' parameter is required" unless $arg{table};

  my $count = Stocks::DB::select ( table => $arg{table},
  			       fields => [qw(count(*))],
			       returns => 'scalar' 
			      );

  return $count
} # _get_count


# Is this private attribute ?
# Private attributes don't have underlying DB field
# Private class method
# ARG: attr name 
# RET: boolean

sub _is_private_attr {
   my $attr = shift;

   croak 'no attribute name was passed' unless $attr;

   return 1 if substr ($attr, 0, 1) eq '_';
   return
}

# Convert perl array to Pg array
# Private class method
# ARG: array
# RET: string

sub _array_to_pgarray {
    my @array = @_;
    
    return '{}' unless @array;

    my $str = '{'.(join(',', @array)).'}';
    
    return $str
}

# Convert Pg array string to perl array
# Private class method
# ARG: str
# RET: arrayref

sub _pgarray_to_array {
   my $str = shift;   

   return unless $str;
   croak "postgres array string required" unless $str =~ /\{$RE{list}{-pat=>'\s*\w+\s*'}{-sep=>','}\}/;

   $str =~ tr/{}//d;
   my @subs = split (',',$str);
  
   return \@subs
}


# Modify name so that case-sensitive PG searches work
# Private class method
# ARG: str reference
# RET: str
#
sub _normalize_name {
    my $name_ref = shift;

    croak "I need scalar ref !" unless (ref $name_ref eq 'SCALAR');

# More than one word in a name - capitalize all
    my @words = split (' ',$$name_ref);
    @words = map { ucfirst (lc($_)) } @words;
    $$name_ref = join' ', @words;

    return $$name_ref

} # _normalize_name


# Sort array of hashes by given field
# numerically or asciibetically
# Private Class Method
# ARG: recs  => arrayref
#      field => str
#      order => 'asc' | 'desc'
# RET: sorted array of hashes
#
sub sort_array {
  my %arg = @_;
  my $recs = $arg{recs};
  my $fieldname = $arg{fieldname};
  my $order = uc $arg{order} || 'ASC';
  my $field;

  croak "need 'recs' param " unless $recs;
  croak "need 'fieldname' param " unless $fieldname;
  
  eval {
  $field = $recs->[0]{$fieldname}; 
  };

  croak "Field '$fieldname' does not exist: ". $EVAL_ERROR unless $field;

if ($field =~ /^$RE{num}{int}/) {
  return sort {$b->{$fieldname} <=> $a->{$fieldname}} @$recs if $order eq 'DESC';
  return sort {$a->{$fieldname} <=> $b->{$fieldname}} @$recs
}else {
  return sort {$b->{$fieldname} cmp $a->{$fieldname}} @$recs if $order eq 'DESC';
  return sort {$a->{$fieldname} cmp $b->{$fieldname}} @$recs
}

} # sort_array

1;


__END__

=head1 Stocks::Base

Stocks::Base -- Common FN methods and utilities

=head1 VERSION

This documentation refers to Stocks::Base version 1.0.0

=head1 SYNOPSIS

 with 'Stocks::Base';

=head1 DESCRIPTION

  This role is to be consumed by all classes with underlying tables

=head1 SUBROUTINES/METHODS

=head2 BUILDARGS

  Standard initializer. We encrypt password attribute in it before building an object.

=head2 BUILD

  Show debug info after object is build

=head2 save 
  
  Object method. Save current object into DB

=head2 delete

  Object method. Delete current object from DB. 'id' property must be set.

=head2 get_attributes
  
  Object method. Returns attribute=>value hash for this object (including base object)

=head2 get_private_attributes

  Object method. Returns all private attributes as attribute=>value hash (including base object)


=head2 get_defaults
  
  Object Method. Returns default=>value hash for this object (including base object)

=head2 dump 

  Print object dump

=head2 _get_count($table_name);

  Private class method. Return number of rows in a table. Table parameter is required.
  Croaks with an error if it wasn't supplied.

=head2 _find

  Private class method. Look for records in given DB table. Return array of hashrefs/arrayrefs 
  depending on value in 'returns'. 'table', 'field' and 'value' are required parameters

  ARGS: field : field to search on
        value : value for the field
        order_by : sort field
        order : sort order (ASC/DESC) (opt) def ASC 
        returns : type of result returned : 'hash', 'array', 'scalar' 

=head2 _is_private_attr($attr);

Is passed attribute private? Returns boolean. Private attributes don't have fields 
in DB table associated with them. Any attribute with name that starts with '__' is 
considered private

=head2 _array_to_pgarray(@arr)

  Private class method. Convert perl array to Postgres array. Returns string.

=head2 _pgarray_to_array

  Private class method. Convert Postgres array to perl array. Returns arrayref

=head2 _normalize_name
  
  Private method. Uppercases first letter of all words in a string, lowercases the rest.
  Modifies string passed as ref in place.  In addition, returns converted string


=head1 DIAGNOSTICS

=over 2


=back

=head1 CONFIGURATION AND ENVIRONMENT
      
Moose::Role : CPAN
Carp 	    : CPAN
Regexp::Common : CPAN

=over 2

There's no restrictions on consuming class in this release

=back

=head1 DEPENDENCIES

=over 2

  	version     : Version control - CPAN
	Moose::Role : OO system - CPAN
	Carp       : Diagnostics - CPAN
	Data::Dumper    : Debug info printout - CPAN
	Smart::Comments : Debug tools - CPAN

        
=back

=head1 INCOMPATIBILITIES

None known in this release.

=head1 BUGS AND LIMITATIONS

 There are no known bugs in this module.

 Please report problems to Dmitri Ostapenko  (<d@perlnow.com>)

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
