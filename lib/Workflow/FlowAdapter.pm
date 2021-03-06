package Workflow::FlowAdapter;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw/run_workflow_flow extract_xml_hashref/;

use File::Basename;
use File::Slurp qw/read_file/;
use File::Spec;
use File::Temp;
use Workflow ();
use Workflow::LsfParser;
use XML::Simple;

use strict;
use warnings;


sub run_workflow_flow {
    require Flow;

    my ($use_lsf, $wf_repr, %inputs) = @_;

    my $xml = extract_xml_hashref($wf_repr);
    add_output_property_list_if_needed($xml);

    my $resources = parse_resources($xml);

    my $xml_text = XMLout($xml);
    my $plan_id = _get_plan_id($xml_text);

    my $result;
    if ($use_lsf) {
        $result = Flow::run_workflow_lsf($xml_text, \%inputs,
            $resources, $plan_id);
    } else {
        $result = Flow::run_workflow($xml_text, \%inputs, $resources, $plan_id);
    }

    unless(defined $result) {
        push @Workflow::Simple::ERROR, Workflow::FlowAdapter::Error->create(error => 'Workflow failed to complete.');
    }

    return $result;
}


sub extract_xml_hashref {
    my $wf_repr = shift;

    my $xml_text;
    my $wf_object;

    my $r = ref($wf_repr);
    if ($r) {
        if ($r eq 'GLOB') {
            $xml_text = $wf_repr;
        } elsif (UNIVERSAL::isa($wf_repr, 'Workflow::Operation')) {
            $xml_text = $wf_repr->save_to_xml;
            $wf_object = $wf_repr;
        } else {
            die 'unrecognized reference';
        }
    } elsif (!($wf_repr =~ m/\n/) && -s $wf_repr) {
        $xml_text = read_file($wf_repr);
    } else {
        $xml_text = $wf_repr;
    }

    unless ($wf_object) {
        $wf_object = Workflow::Operation->create_from_xml($xml_text);
    }

    return XMLin($xml_text, KeyAttr => [],
        ForceArray => [
            'inputproperty',
            'link',
            'operation',
            'outputproperty',
            'property',
        ]);
}


sub add_output_property_list_if_needed {
    my $xml = shift;

    if ($xml->{operationtype}{typeClass}
            eq 'Workflow::OperationType::Command') {
        $xml->{operationtype}{outputproperty} = _command_output_properties(
            $xml->{operationtype}{commandClass})
    }
}


sub _command_output_properties {
    my $command_class = shift;


    my $meta = $command_class->__meta__;
    my @output_properties =
        map {$_->property_name}
        grep {$_->can('is_output') && $_->is_output} $meta->properties;

    return \@output_properties;
}


sub parse_resources {
    my $xml = shift;

    if (exists $xml->{operation} and ref $xml->{operation} eq 'ARRAY') {
        my %resources;
        for my $op (@{$xml->{operation}}) {
            $resources{children}{$op->{name}} = parse_resources($op);
        }
        return \%resources;
    } else {
        return _op_resource_requests($xml);
    }
}


sub _get_plan_id {
    my $xml_text = shift;

    my $fh = File::Temp->new();
    $fh->print($xml_text);
    $fh->close();
    my $filename = $fh->filename;

    my $executable = File::Spec->join(File::Basename::dirname(__FILE__),
        'Cache', 'save.pl');
    my $plan_id = `$^X $executable $filename`;
    if ($? or not $plan_id) {
        die "'$^X $executable $filename' did not return successfully";
    }
    chomp($plan_id);

    return $plan_id;
}


sub _op_resource_requests {
    my $op = shift;
    if (!exists $op->{operationtype}) {
        die "Operation $op->{name} with no operation type!";
    }

    my $optype = $op->{operationtype};
    my %lsf;
    if (exists $optype->{lsfQueue}) {
        $lsf{queue} = $optype->{lsfQueue};
    }

    if (exists $optype->{lsfResource}) {
        my $res = Workflow::LsfParser::get_resource_from_lsf_resource(
                $optype->{lsfResource})->as_xml_simple_structure;
        my $queue_override = delete $res->{queue};
        $lsf{queue} = $queue_override if $queue_override;
        $lsf{resources} = _translate_workflow_resource(%$res);
    }

    return \%lsf;
}


sub _translate_workflow_resource {
    my %r = @_;

    my %f = (
        limit => {},
        reserve => {},
        request => {},
    );

    $f{request}{max_cores} = $r{maxProc} if exists $r{maxProc};
    if (exists $r{minProc}) {
        $f{request}{min_cores} = $r{minProc};
        if (!exists $r{maxProc} || $r{maxProc} < $r{minProc}) {
            $f{request}{max_cores} = $r{minProc};
        }
    }


    if (exists $r{tmpSpace}) {
        $f{request}{temp_space} = $r{tmpSpace};
        $f{reserve}{temp_space} = $r{tmpSpace} if exists $r{useGtmp};
    }

    $f{reserve}{memory} = $r{memRequest} if exists $r{memRequest};
    $f{limit}{max_resident_memory} = $r{memLimit} if exists $r{memLimit};

    $f{limit}{cpu_time} = $r{timeLimit} if exists $r{timeLimit};

    return \%f;
}


1;
