#!/usr/bin/env perl
# -*- cperl -*-

=head1 NAME

RUM::ConfigFile - A RUM configuration file

=head1 SYNOPSIS

  use RUM::ConfigFile;

Parse a config file

  open my $in, "<", "rum.config_zebrafish";
  my $config = RUM::ConfigFile->parse($in);

Format a configuration

  my $config_text = $config->to_str();

  # Get list of field names
for my $field (RUM::ConfigFile->fields()) {
  ...
}

  my $default_config_hashref = config_defaults();

=head1 DESCRIPTION

This package provides utilities for parsing and formatting a Rum config file.

=cut

package RUM::ConfigFile;

use strict;
no warnings;

use Getopt::Long;
use Carp;
use FindBin qw($Bin);
FindBin->again;

our @FIELDS = qw(gene_annotation_file
                 bowtie_bin
                 blat_bin
                 mdust_bin
                 bowtie_genome_index
                 bowtie_gene_index
                 blat_genome_index);

=head2 Creating a configuration

=over 4

=cut

=item RUM::ConfigFile->parse($in)

Parse the open filehandle $in and return a RUM::ConfigFile object.

=back

=cut

sub parse {
    my ($class, $in, %options) = @_;
    my %self;

    for my $field (@FIELDS) {
        local $_ = <$in>;
        croak "Not enough lines in config file" unless defined $_;
        chomp;
        my $root = "$Bin/../";
        my $abs_path = File::Spec->rel2abs($_, $root);
        $self{$field} = $abs_path;
    }

    while (defined(local $_ = <$in>)) {
        warn "Extra line '$_' in config file will be ignored" 
            unless $options{quiet};
    }
    
    return bless \%self, $class;
}

=head2 Properties

=over 4

=item $config->gene_annotation_file

=item $config->bowtie_bin

=item $config->blat_bin

=item $config->mdust_bin

=item $config->bowtie_genome_index

=item $config->bowtie_gene_index

=item $config->blat_genome_index

=back

=cut

sub gene_annotation_file { shift->{gene_annotation_file} }
sub bowtie_bin { shift->{bowtie_bin} }
sub blat_bin { shift->{blat_bin} }
sub mdust_bin { shift->{mdust_bin} }
sub bowtie_genome_index { shift->{bowtie_genome_index} }
sub bowtie_gene_index { shift->{bowtie_gene_index} }
sub blat_genome_index { shift->{blat_genome_index} }

=head2 Other Methods

=over 4

=item $config->make_absolute($prefix)

Change this configuration object so that any relative paths are
converted to absolute paths by prepending $prefix.

=cut

sub make_absolute {
    my ($self, $prefix) = @_;
    for my $key (@FIELDS) {
        $self->{$key} = File::Spec->rel2abs($self->{$key}, $prefix);
    }
}

=item $config->to_str()

Return a string representing the config file.

=cut

sub to_str {
    my ($self) = @_;
    my %config = %{ $self };
    # Check for missing fields and log a warning
    my @missing = $self->missing_fields();
    warn "Missing these config fields: ". join(", ", @missing)
        if @missing;
            
    # Make sure are fields are defined
    my @values = map($_ || "", @config{@FIELDS});

    return join("", map("$_\n", @values));
}

=item config_defaults

Return a hashref containing sensible defaults for a configuration.

=cut

sub config_defaults {
    return {
        bowtie_bin => "bowtie",
        blat_bin   => "blat",
        mdust_bin  => "mdust"
    };
}

=item fields

Return an array of the fields that should be in a configuration file.

=cut

sub fields {
    return @FIELDS;
}

=item missing_fields

Return a list of fields that are missing from this config.

=cut

sub missing_fields {
    my ($self) = @_;
    return grep { not $self->{$_} } @FIELDS;
}

=back

=head1 AUTHOR

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012, University of Pennsylvania

=cut


1;
