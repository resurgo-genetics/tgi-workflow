
package Workflow::Operation;

use strict;
use warnings;
use XML::Simple;

class Workflow::Operation {
    has => [
        name => { is => 'Text' },
        workflow_model => { is => 'UR::Object', id_by => 'workflow_model_id', is_optional => 1 },
        operation_type => { is => 'Workflow::OperationType', id_by => 'workflow_operationtype_id' },
        is_valid => { is => 'Boolean', default_value=>0, doc => 'Flag set when validate has run' },
        executor => { is => 'Workflow::Executor', id_by => 'workflow_executor_id', is_optional => 1 },
        parallel_by => { is => 'String', is_optional=>1 },
        filename => { is => 'String', is_optional => 1 }
    ]
};

sub dependent_operations {
    my $self = shift;
    
    my %operations = map {
        $_->right_operation->id => $_->right_operation
    } Workflow::Link->get(left_operation => $self);
    
    return values %operations;
}

sub depended_on_by {
    my $self = shift;
    
    my %operations = map {
        $_->left_operation->id => $_->left_operation
    } Workflow::Link->get(right_operation => $self);
    
    return values %operations;
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    if (!$self->workflow_model && !$self->executor) {
        $self->executor(Workflow::Executor::SerialDeferred->get);
    }

    return $self;
}

sub create_from_xml {
    my ($class, $filename) = @_;

    my $struct = XMLin($filename, KeyAttr=>[], ForceArray=>[qw/operation property inputproperty outputproperty link/]);
    my $self = $class->create_from_xml_simple_structure($struct,filename=>$filename);

    return $self;
}

sub create_from_xml_simple_structure {
    my $class = shift;
    my $struct = shift;
    my %params = (@_);

    my $self;

    ## i dont like this at all
    ## delegate sub-models
    if ($class eq __PACKAGE__ && (exists $struct->{operationtype} && $struct->{operationtype}->{typeClass} eq 'Workflow::OperationType::Model' || $struct->{workflowFile})) {

        $self = Workflow::Model->create_from_xml_simple_structure($struct,%params);
    } else {
        $params{parallel_by} = $struct->{parallelBy} if $struct->{parallelBy};

        my $optype = Workflow::OperationType->create_from_xml_simple_structure($struct->{operationtype});
        $self = $class->create(
            name => $struct->{name},
            operation_type => $optype,
            %params
        );
    }

    return $self;
}

sub as_xml_simple_structure {
    my $self = shift;

    my $struct = {
        name => $self->name,
        operationtype => $self->operation_type->as_xml_simple_structure
    };

    $struct->{parallelBy} = $self->parallel_by if ($self->parallel_by);

    if (!$self->workflow_model) {
        $struct->{executor} = $self->executor->class;
    }

    return $struct;
}

sub save_to_xml {
    my $self = shift;
    my %args = @_;

    return XMLout($self->as_xml_simple_structure, KeyAttr=>[], RootName=>'operation', XMLDecl=>1, %args);
}

sub set_all_executor {
    my ($self,$exec) = @_;

    $self->executor($exec);
}

sub validate {
    my ($self) = @_;
    
    $self->is_valid(1);
    return ();
}

sub operations_in_series {
    my $self = shift;

    return ($self);
}

sub generate_command {
    my ($self, $class_name) = @_;

    die 'must provide a class name to create' unless $class_name;

    my $inputs = $self->operation_type->input_properties;
    my $outputs = $self->operation_type->output_properties;

    my $has = [
        (map { 
            $_ => { is_input => 1 }
        } @{ $inputs }),
        (map {
            $_ => { 
                is_output => 1,
                is_optional => 1
            }
        } grep { $_ ne 'result' } @{ $outputs }),
        workflow_operation_id => {
            is_param => 1,
            type => 'Workflow::Operation',
            is_constant => 1,
            is_class_wide => 1,
            value => $self->id
        }
    ];

    my $class = UR::Object::Type->define(
        class_name => $class_name,
        extends => [ 'Workflow::Operation::Command' ],
        english_name => $self->name,
        has => $has
    );

    return $class;
}

sub execute {
    my $self = shift;
    my %params = (@_);

    unless ($self->is_valid) {
        my @errors = $self->validate;
        unless (@errors == 0) {
            die 'cannot execute invalid workflow';
        }
    }
    
    unless (exists $params{store} && $params{store} && $params{store}->can('sync')) {
        $params{store} = Workflow::Store::None->get();
    }

    {
        my %ikeys = map { $_ => 1 } keys %{ $params{input} };
        foreach my $k (@{ $self->operation_type->input_properties }) {
            delete $ikeys{$k} if exists $ikeys{$k};
        }

        if (scalar keys %ikeys) {
            Carp::croak('execute: Extra inputs provided');
            return;
        }
    }

    my $operation_instance = Workflow::Operation::Instance->create(
        operation => $self,
        store => $params{store},
        output_cb => $params{output_cb},
        error_cb => $params{error_cb}
    );
    $operation_instance->input($params{input} || {});
    $operation_instance->output({});

    $operation_instance->execute;
    $operation_instance->sync;

    return $operation_instance;
}

sub wait {
    my $self = shift;
    
    $self->executor->wait($self);
}

sub detach {
    my $self = shift;
    
    $self->executor->detach($self);
}

1;
