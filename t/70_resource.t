#!/usr/bin/env perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT}=1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS}=1;
}

use strict;
use warnings;

use Test::More tests => 4;

use above 'Workflow';

require_ok('Workflow');
require_ok('Workflow::Resource');

my $resource = Workflow::Resource->create(mem_limit => 100);
$resource->min_proc(5);

ok($resource->mem_limit == 100, "Resource sets mem_limit");
ok($resource->min_proc == 5, "Resource sets min_proc");
