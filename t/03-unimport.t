#!perl -T

use warnings;
use strict;
use Test::More tests => 1;

BEGIN {
    require_ok('lib::tree') || BAIL_OUT("Could not require 'lib::tree'!\n");
}

# We are using the unimport function directly to emulate someone
# saying 'no lib:tree ( ... );'

