#!/usr/bin/env perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT}=1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS}=1;
}

use strict;
use warnings;

use Test::More;

my $static_test_count = 9;

use above 'Workflow';
my @subcommands = Workflow::Test::Command->sub_command_classes;

plan tests => $static_test_count + scalar(@subcommands);

require_ok('Workflow');
require_ok('Workflow::OperationType::Command');

{
    my $o1 = Workflow::OperationType::Command->get('Workflow::Test::Command::Sleep');

    ok($o1,'get');
    is($o1->command_class_name,'Workflow::Test::Command::Sleep','command class name');
    
    ok(eq_set($o1->input_properties,['seconds']),'input properties');
    ok(eq_set($o1->output_properties,['result']),'output properties');
    is($o1->lsf_queue,'short','lsf queue');
    is($o1->lsf_resource,'rusage[mem=4000] span[hosts=1]','lsf resource');
    
    my $o2 = Workflow::OperationType::Command->create(
        command_class_name => 'Workflow::Test::Command::Sleep'
    );
    is($o2->id,$o1->id,'create returned same object as get');
}

# try to instantiate all our test command modules, just to be sure

foreach my $cmd (@subcommands) {
    my $o = Workflow::OperationType::Command->create(
        command_class_name => $cmd
    );
    
    isa_ok($o,'Workflow::OperationType::Command',$cmd);
}


