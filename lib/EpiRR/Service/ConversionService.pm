package EpiRR::Service::ConversionService;

use strict;
use warnings;
use Moose;
use Carp;
use EpiRR::Model::Dataset;
use EpiRR::Model::RawData;

has 'raw_data_service' => (
    is  => 'rw',
    isa => 'EpiRR::Service::RawDataService',
);
has 'meta_data_service' => (
    is  => 'rw',
    isa => 'EpiRR::Service::MetaDataService',
);
has 'model' =>  ( is => 'rw', isa => 'EpiRR::Model' )
;

sub db_to_simple {
    my ( $self, $dsv ) = @_;

    confess("No DatasetVersion passed") unless $dsv;
    confess("Argument must be a DatasetVersion")
      unless $dsv->isa("EpiRR::Model::Result::DatasetVersion");

    my $d = EpiRR::Model::Dataset->new(
        project     => $dsv->dataset()->project()->name(),
        status      => $dsv->status()->status(),
        accession => $dsv->full_accession(),
        local_name  => $dsv->local_name(),
        description => $dsv->description()
    );

    for my $m ( $dsv->meta_datas ) {
        $d->set_meta_data( $m->name(), $m->value() );
    }

    for my $r ( $dsv->raw_datas ) {
        my $x = EpiRR::Model::RawData->new(
            archive      => $r->archive()->name(),
            primary_id   => $r->primary_id(),
            secondary_id => $r->secondary_id(),
            archive_url  => $r->archive_url,
        );
        $d->add_raw_data($x);
    }

    return $d;
}

sub simple_to_db {

}

__PACKAGE__->meta->make_immutable;
1;
