#!/usr/bin/perl
#
# Reset USDCAD_LAST and EURCAD_LAST in quote table for the next day.
# Should run close to midnight.
# Stocks project.

use strict;
use Stocks::Quote;

# Reset USDCAD_LAST in quote table to current fx
Stocks::Quote::cache_usdcad();
Stocks::Quote::cache_eurcad();
