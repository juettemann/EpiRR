package EpiRR::Parser::TextFileParser;

use strict;
use warnings;
use Carp;
use feature qw(switch);
use Moose;

use EpiRR::Model::Dataset;
use EpiRR::Model::RawData;

use Data::Dumper;

=head1 NAME

EpiRR::Parser::TextFileParser

Parses text files to produce EpiRR::Model::Dataset objects.
Each file can contain one dataset.
Each line consists of a number of tokens, tab separated.
The first token must define the type of information on the line.
The order of the lines is not significant

=head2 PROJECT

One required. Name of the Project to which this reference dataset belongs. e.g.

PROJECT	BLUEPRINT

=head2 RAW_DATA

One or more required. Should be an archive name, and one or two accessions to find the data in that archive e.g.

RAW_DATA	ENA	SRX007379
RAW_DATA	ARRAY_EXPRESS	E-MTAB-2000	Gifu Mock2

The precise meaning and number of accessions required vary by archive. The preferred entity to reference is something akin to a SRA experiment.
Array Express does not have accession numbers visisble for an equivalent entity, so two accessions are required.

=head2 ACCESSION

One required when updating an existing dataset. 

=head2 LOCAL_NAME

Optional, one or fewer may be used. The name used within the project that produced it. e.g.

LOCAL_NAME	CEMT001

=head2 DESCRIPTION

Optional, one or fewer may be used. Free text description of the reference dataset.
The preferred method of discovering what a dataset represents is through the archived meta data. e.g.

DESCRIPTION	Chronic Lymphocytic Leukemia

=cut

has 'errors' => (
    traits => ['Array'],
    is     => 'ro',
    isa    => 'ArrayRef[Str]',
    handles =>
      { push_error => 'push', error_count => 'count', get_error => 'get' },
    default => sub { [] }
);
has 'file_path' => ( is => 'ro', isa => 'Str', required => 1 );
has 'file_handle' => ( is => 'rw', isa => 'FileHandle' );
has 'dataset' => (
    is      => 'ro',
    isa     => 'EpiRR::Model::Dataset',
    default => sub { EpiRR::Model::Dataset->new() },
);
has '_token_set' => ( is => 'rw', isa => 'ArrayRef' );

sub add_error {
    my ( $self, $text ) = @_;

    $text .= ' at line ';
    $text .= $self->file_handle()->input_line_number();

    $self->push_error($text);
}

sub handle_project {
    my ( $self, $tokens ) = @_;
    my ($project) = @$tokens;

    if ( scalar(@$tokens) > 1 ) {
        $self->add_error("Too many tokens for PROJECT");
    }
    if ( !$project ) {
        $self->add_error("No project name given for PROJECT");
    }
    elsif ( defined $project && $self->dataset()->project() ) {
        $self->add_error("Additional PROJECT name");
    }
    else {
        $self->dataset()->project($project);
    }
}

sub handle_raw_data {
    my ( $self, $tokens ) = @_;
    my ( $archive, $primary_id, $secondary_id ) = @$tokens;

    if ( scalar(@$tokens) > 3 ) {
        $self->add_error("Too many tokens for RAW_DATA");
    }
    elsif ( !$archive ) {
        $self->add_error("No archive given for RAW_DATA");
    }
    elsif ( !$primary_id ) {
        $self->add_error("No primary ID given for RAW_DATA");
    }
    else {
        my $rd = EpiRR::Model::RawData->new(
            archive      => $archive,
            primary_id   => $primary_id,
            secondary_id => $secondary_id
        );
        $self->dataset()->add_raw_data($rd);
    }
}

sub handle_local_name {
    my ( $self, $tokens ) = @_;
    my ($value) = @$tokens;

    if ( scalar(@$tokens) != 1 ) {
        $self->add_error("Should be one token for LOCAL_NAME");
    }
    elsif ( !$value ) {
        $self->add_error("No value given for LOCAL_NAME");
    }
    elsif ( $self->dataset()->local_name() ) {
        $self->add_error("Additional LOCAL_NAME");
    }
    else {
        $self->dataset()->local_name($value);
    }
}

sub handle_accession {
    my ( $self, $tokens ) = @_;
    my ($value) = @$tokens;

    if ( scalar(@$tokens) != 1 ) {
        $self->add_error("Should be one token for ACCESSION");
    }
    elsif ( !$value ) {
        $self->add_error("No value given for ACCESSION");
    }
    elsif ( $self->dataset()->accession() ) {
        $self->add_error("Additional ACCESSION");
    }
    else {
        $self->dataset()->accession($value);
    }
}

sub handle_description {
    my ( $self, $tokens ) = @_;
    my ($value) = @$tokens;

    if ( scalar(@$tokens) != 1 ) {
        $self->add_error("Should be one token for DESCRIPTION");
    }
    elsif ( !$value ) {
        $self->add_error("No value given for DESCRIPTION");
    }
    elsif ( $self->dataset()->description() ) {
        $self->add_error("Additional DESCRIPTION");
    }
    else {
        $self->dataset()->description($value);
    }
}

sub parse {
    my ($self) = @_;

    $self->_open();
    my ( $type, $tokens, $tokenset );
    while ( $tokenset = $self->next_token_set() ) {

        my ( $type, $tokens ) = @{$tokenset};
        given ($type) {
            when ('PROJECT') {
                $self->handle_project($tokens);
            }
            when ('RAW_DATA') {
                $self->handle_raw_data($tokens);
            }
            when ('LOCAL_NAME') {
                $self->handle_local_name($tokens);
            }
            when ('ACCESSION') {
                $self->handle_accession($tokens);
            }
            when ('DESCRIPTION') {
                $self->handle_description($tokens);
            }
            default {
                $self->add_error( "Unknown line type - $type", 1 );
            }
        }
    }
    if ( !$self->dataset()->project() ) {
        $self->push_error( "No PROJECT given");
    }
    if ( $self->dataset()->raw_data_count() == 0 ) {
        $self->push_error( "No RAW_DATA given");
    }
    $self->_close();
}

sub _close {
    my ($self) = @_;
    close $self->file_handle();
}

sub _open {
    my ($self) = @_;
    my $file_path = $self->file_path();
    open my $fh, '<', $file_path or croak("Could not open $file_path: $!");
    $self->file_handle($fh);
}

sub next_token_set {
    my ($self) = @_;
    my ( $type, @tokens );
    my $fh = $self->file_handle();
    croak "No file handle!" if !$fh;

    while (<$fh>) {
        chomp;
        next if /^#/;
        @tokens = split /\t/;
        $type   = shift @tokens;
        return [ $type, \@tokens ];
    }
    return undef;
}
__PACKAGE__->meta->make_immutable;

1;