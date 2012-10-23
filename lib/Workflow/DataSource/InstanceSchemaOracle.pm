use strict;
use warnings;

package Workflow::DataSource::InstanceSchemaOracle;

use Workflow;

class Workflow::DataSource::InstanceSchemaOracle {
    is => ['UR::DataSource::Oracle'],
    type_name => 'workflow datasource instanceschema',
};

sub server {
    "gscprod";
}

sub login {
    "wrkflo_user";
}

sub auth {
    "wfl0us3r";
}

sub owner {
    "WORKFLOW";
}

sub table_and_column_names_are_upper_case { 1; }

sub _get_next_value_from_sequence {
my($self,$sequence_name) = @_;

    return $self->SUPER::_get_next_value_from_sequence($self->owner . '.' . $sequence_name);
}

sub _sync_database {
    my $self = shift;

    my $dbh = $self->get_default_handle;
    unless ($dbh->do("alter session set NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS'")
            and
            $dbh->do("alter session set NLS_TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SSXFF'"))
    {
        Carp::croak("Can't set date format: $DBI::errstr");
    }
    $self->SUPER::_sync_database(@_);
}

sub _my_data_source_id {
	"Workflow::DataSource::InstanceSchema";
}

1;