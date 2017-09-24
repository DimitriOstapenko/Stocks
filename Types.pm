package Types;
 
# predeclare our own types

  use MooseX::Types 
      -declare => [qw( CountryCodeType EmailType EmailSubscriptionType Exchange HistDateTime LanguageType NegInt PosInt 
      	 	       PosFloat PhoneNumType StateProvCodeType SubscriptionType TimeStamp TType US_Can_PostalCodeType 
		       UserType
      		   )];

  use Moose::Util::TypeConstraints;

# import builtin types

  use MooseX::Types::Moose qw(Int HashRef Object);
  use DateTime;

# type definitions

  type 'CountryCodeType',
      where { $_ =~ /^[A-Z]{2}$/},
      message { 'Valid 2-letter country code is required '};

  subtype 'Date',
    as 'Str',
    where { $_=~ /^\d{4}-\d{1,2}-\d{1,2}/},
    message {'Valid date string is required, not "'.$_.'"'};

  subtype 'DateTime_',
    as 'Str',
    where { $_ =~ /^\d{4}(-\d{2}){2}(\s+\d{1,2}(:\d{1,2}){1,2})?$/},
    message {'Valid datetime string is required, not "'.$_.'"'};

#  subtype 'DateTime',
#     as 'Object',
#     where { $_->isa('DateTime') },
#     message { "Valid DateTime object is required" };

#  coerce 'DateTime'
#      => from 'HashRef'
#          => via { DateTime->new(%$_, time_zone => 'local') }
#      => from 'Str'
#          => via {
#             require DateTime::Format::DateManip;
#             DateTime::Format::DateManip->parse_datetime($_);
#             };

  type 'EmailType',
      where { !$_  ||  $_ =~ /^[a-zA-Z0-9\+\.\_\-]+@[a-zA-Z0-9\.\-]+$/},
      message { "Valid email adddress is required - got '$_'"};

  subtype 'HistDateTime'
    => as 'DateTime'
    => where { $_ <= DateTime->now(time_zone => 'local') },
    => message {"($_): Valid date in the past is required"};

#  coerce 'HistDateTime'
#      => from 'HashRef'
#          => via { DateTime->new(%$_ , time_zone => 'local') }
#      => from 'Str'
#          => via {
#             require DateTime::Format::DateManip;
#             DateTime::Format::DateManip->parse_datetime($_);
#             };

#  subtype 'FutureDateTime'
#    => as 'DateTime'
#    => where { $_ >= DateTime->now(time_zone => 'local') },
#    => message {"Valid date in the future is required"};

#  coerce 'FutureDateTime'
#      => from 'HashRef'
#          => via { DateTime->new(%$_, time_zone => 'local') }
#      => from 'Str'
#          => via {
#             require DateTime::Format::DateManip;
#             DateTime::Format::DateManip->parse_datetime($_);
#             };

  type 'PhoneNumType',
      where { $_  =~ /^\d{3}\-\d{3}\-\d{4}$/},
      message { "Valid phone number is required "};

  subtype 'PosInt', 
      as 'Int', 
      where { $_ > 0 },
      message { "Positive value is required" };
  
  subtype 'NegInt',
      as 'Int',
      where { $_ < 0 },
      message { "Negative value is required" };

  subtype 'PosFloat',
      as 'Num',
      where { $_ > -0.01},
      message { 'Non-negative real value is required' };

  subtype 'PcFloat',
      as 'Num',
      where { $_ >= -100 },
      message {  'Real value > -100 is required' };

  subtype 'PosPcFloat',
      as 'Num',
      where { $_ >= 0 && $_ < 100},
      message { 'Real value >= 0 && <100 is required' };

  type 'StateProvCodeType',
      where { $_ =~ /^[A-Z]{2}$/ },
      message { "Valid 2-letter state/prov code is required - got '$_'"};

  type 'TimeStamp',
#    where { $_ eq '' || $_ =~ /^\d{4}\-\d{1,2}\-\d{1,2}\s+\d{1,2}\:\d{1,2}\(:\d{1,2})?$/ },
    where { $_ eq '' || $_ =~ /^\d{4}(-\d{1,2}){2}(\s+\d{1,2}(:\d{1,2}){1,2})(am|pm)?$/},
    message { "Valid timestamp is required - got '$_'" };

  subtype 'TType',
      as 'Int',
      where {$_ >=0 && $_ < 9 },
      message { "Transaction type must be in the range [0..8]" };

  type 'US_Can_PostalCodeType',
      where { !$_ || $_ =~ /^((\w\d){3}|(\d{5})|(\d{5}-\d{4}))$/},
      message { "Valid US/CA postal code is required - got '$_'"};

  enum 'CurType' => [('CAD', 'USD', 'EUR', 'GLD', '')];   
  enum 'Exchange' => [('TSX', 'NYSE', 'AMEX', 'NASD', '' )];
  enum 'LanguageType' => [qw(En Fr)];
  enum 'EmailSubscriptionType' => [qw(port trades news)];
  enum 'SubscriptionType' => [qw(Search Subs2 Subs3)];
  enum 'UserType' => [qw(web local admin)];
  enum 'TitleType' => [qw(Mr. Mrs. Ms. Dr.)];
  enum 'PriceModelType' => [qw(share trade)];

# Type Coercion

  coerce 'PosInt',
      from 'Int',
          via { 1 },
      from 'Str',
          via { 0+$_ };

1;
