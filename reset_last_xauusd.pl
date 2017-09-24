#!/usr/bin/perl
#
# Reset XAUUSD_LAST in quote table for the next day. Should run close to midnight.
# Stocks project.

use strict;
use Stocks::Quote;

# Reset XAUUSD_LAST in quote table to current price
Stocks::Quote::cache_xauusd();
