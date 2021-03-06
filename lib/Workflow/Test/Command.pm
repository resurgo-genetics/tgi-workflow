
package Workflow::Test::Command;

use strict;
use warnings;
use Workflow;

class Workflow::Test::Command {
    is => ['Command'],
    english_name => 'workflow-test command',
};

sub command_name {
    my $self = shift;
    my $class = ref($self) || $self;
    return 'workflow-test' if $class eq __PACKAGE__;
    return $self->SUPER::command_name(@_);
}

sub help_brief {
    "modularized commands for testing Workflow"
}

1;
