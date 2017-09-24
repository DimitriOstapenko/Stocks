# ContactBase.pm -- base class for all contact-related classes
#
# by Dmitri Ostapenko, feb 2009 - d@perlnow.com

package Stocks::ContactBase;

use Moose::Role;
with 'Stocks::Base';

requires qw(get find found save delete get_attributes get_defaults dump);

use Carp;

use version; our $VERSION = qv('1.0.0');
use strict;

use Stocks::Types;

use Data::Dumper;
#use Smart::Comments;


# N.B!  Please keep this table current
#
#                          Table "public.contact_base"
#     Column      |         Type          |               Modifiers                
#-----------------+-----------------------+----------------------------------------
# first_name      | character varying(64) | not null default ''::character varying
# middle_name     | character varying(64) | default ''::character varying
# last_name       | character varying(64) | not null default ''::character varying
# home_phone      | phonenumtype          | 
# work_phone      | phonenumtype          | 
# extension       | smallint              | 
# cell_phone      | phonenumtype          | 
# email1          | emailtype             | 
# email2          | emailtype             | 
# email3          | emailtype             | 
# street_addr1    | character varying(64) | default ''::character varying
# street_addr2    | character varying(64) | default ''::character varying
# suite_apt       | character varying(24) | 
# city            | character varying(64) | default ''::character varying
# country_code    | countrycodetype       | 
# state_prov_code | stateprovcodetype     | 
# postal_zip      | us_can_postalcodetype | 
# company_name    | character varying(64) | default NULL::character varying
# title           | titletype             | 



#
# Objects of this class will have following attributes: (should be identical to current table schema)
# Giving defaults (even undef) to all attributes is a good idea
#

        has 'first_name' => (is => 'rw', isa => 'Str', required =>1 );                   # First Name
        has 'middle_name' => (is => 'rw', isa => 'Maybe[Str]',default=>'' ); 	         # Middle Name
        has 'last_name' => (is => 'rw', isa => 'Str', required =>1 ); 	   	         # Last Name
        has 'home_phone' => (is => 'ro', isa => 'Maybe[PhoneNumType]', required => 1 );         # Phone Number with the area code (xxx-xxx-xxxx) 
        has 'work_phone' => (is => 'ro', isa=> 'Maybe[PhoneNumType]', default => undef);           # Phone Number with the area code (xxx-xxx-xxxx)
        has 'extension' => (is => 'ro', isa => 'Maybe[Int]', default => undef);          # Extension 
        has 'cell_phone' => (is => 'ro', isa => 'Maybe[PhoneNumType]',default => undef );       # Phone Number with the area code (xxx-xxx-xxxx)
        has 'email1' => (is => 'ro', isa=> 'EmailType', default => '');                  # Primary email address
        has 'email2' => (is => 'ro', isa=> 'EmailType', default => '');                  # Alternative email address
        has 'email3' => (is => 'ro', isa=> 'EmailType', default => '');                  # Alternative email address 2
        has 'street_addr1' => (is => 'ro', isa=> 'Str', default => '');                  # Full street address
        has 'street_addr2' => (is => 'ro', isa=> 'Str', default => '');                  # Full street address 2
        has 'suite_apt' => (is => 'ro', isa=> 'Maybe[Str]', default => undef);           # Suite /Apt # if applicable
        has 'city' => (is => 'rw', isa=> 'Str', default => undef);                       # Full city name
        has 'country_code' => (is => 'rw', isa=> 'Maybe[CountryCodeType]', default => undef);    # 2-letter code (UC)
        has 'state_prov_code' => (is => 'rw', isa=> 'Maybe[StateProvCodeType]', default => undef); # 2-letter code (UC)
        has 'postal_zip' => (is => 'rw', isa=> 'US_Can_PostalCodeType', default => undef);  # Postal | Zip code 
	has 'company_name' => (is => 'ro', isa => 'Maybe[Str]', default=>undef);            # Company name
        has 'title' => (is => 'ro', isa => 'Maybe[TitleType]' );		         # Title (enum)


# Custom initializer - fix all names & codes here
# ARG: none
# RET: $self

sub _build {
    my $self = shift;
    my $fname = $self->first_name;
    my $mname = $self->middle_name;
    my $lname = $self->last_name;
    my $city = $self->city;
    
    return $self unless $lname;

    if ( $fname ) {
       _normalize_name (\$fname);
       $self->first_name($fname);
    }

    if ( $mname ) {
       _normalize_name (\$mname);
       $self->middle_name($fname);
    }

    if ( $lname ) {
       _normalize_name (\$lname);
       $self->last_name($lname);
    }

    if ( $city ) {
       _normalize_name (\$city);
       $self->city($city);
    }

    $self->country_code(uc $self->country_code) if $self->country_code;
    $self->state_prov_code(uc $self->state_prov_code) if $self->state_prov_code;
    $self->postal_zip(uc $self->postal_zip) if $self->postal_zip;

    return $self
}



1;

__END__

=head1 Stocks::ContactBase

Stocks::ContactBase : Contact role to be used in all contact-related classes 

=head1 VERSION

This documentation refers to Stocks::ContactBase version 1.0.0

=head1 SYNOPSIS

 with qw( Stocks::ContactBase );

=head1 DESCRIPTION

This module provides interface to contact_base table, which is base table for all tables that have contact info in them

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=over 2

=head1 CONFIGURATION AND ENVIRONMENT

This role requires following generic methods to be defined in consuming class:
  
   -- get find found save delete get_attributes get_defaults dump

=over 2


=back

=head1 DEPENDENCIES

=over 2

  	version      : Version control - CPAN
	Moose::Role  : OO system - CPAN

	Stocks::Config : Site configs

=back

=head1 INCOMPATIBILITIES

Smart::Comments conflicts with Perl standard debugger

=head1 BUGS AND LIMITATIONS

 There are no known bugs in this module.

Please report problems to Dmitri Ostapenko  (d@perlnow.com)

Patches are welcome.

=head1 AUTHOR

Dmitri Ostapenko (d@perlnow.com)

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2009 Ostapenko COnsulting Inc. All rights reserved.

This module is free software; you can redistribute it and/or modify it under the same 
terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

