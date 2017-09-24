#!/usr/bin/perl
#
# by Dimitri Ostapenko, d@perlnow.com Apr 2008

use strict;
my $dow = (localtime)[6];
my $target_dir = '/home/stocks/backup/stocks'.$dow.'.gz';

print  "This is ", `uname -a`, `date`, " \n";
`/usr/bin/pg_dump --no-acl -d stocks -Z5 > $target_dir`;

