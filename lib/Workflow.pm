package Workflow;

use warnings;
use strict;

use UR;

# this keeps around old parts of the UR::Object API we removed in the 0.01 release
use UR::ObjectV001removed;
use Carp qw{carp};

class Workflow {
    is => ['UR::Namespace'],
    type_name => 'workflow',
};

1;
