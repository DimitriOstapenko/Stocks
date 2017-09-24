#!/usr/bin/perl -w
use strict;
use warnings;

use XML::RSS::Parser;

binmode STDOUT, ':encoding(UTF-8)';

my $parser = XML::RSS::Parser->new;
my $feed = $parser->parse_uri('http://www.cbc.ca/cmlink/rss-topstories');

printf "Title: %s\n", $feed->query('/channel/title')->text_content;

printf "Description: %s\n", $feed->query('/channel/description')->text_content;
