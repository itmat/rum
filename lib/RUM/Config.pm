#!/usr/bin/env perl
# -*- cperl -*-

=head1 NAME

RUM::Config - Utilities for parsing and formatting Rum config file

=head1 SYNOPSIS

  use RUM::Config qw(parse_config
                     format_config
                     config_fields
                     config_defaults
                     parse_organisims);

  # Parse a config file
  open my $in, "<", "rum.config_zebrafish";
  my $config_hashref = parse_config($in);

  # Format a configuration
  my $config_text = format_config(
      "gene-annotation-file" => "foo.txt",
      "bowtie-bin" => "/usr/bin/bowtie",
      ... please see config_fields() for all field names
  );

  # Get list of field names
  for my $field (@config_fields) {
    ...
  }

  my $default_config_hashref = config_defaults();

=head1 DESCRIPTION

This package provides utilities for parsing and formatting a Rum config file.

=head2 Subroutines

=over 4

=cut

package RUM::Config;

use strict;
use warnings;

use Getopt::Long;
use Carp;

our @FIELDS = qw(gene_annotation_file
                 bowtie_bin
                 blat_bin
                 mdust_bin
                 bowtie_genome_index
                 bowtie_gene_index
                 blat_genome_index);

=item RUM::Config->parse($in)

Parse the open filehandle $in and return a RUM::Config object.

=cut

sub parse {
    my ($class, $in, %options) = @_;
    my %self;

    for my $field (@FIELDS) {
        local $_ = <$in>;
        croak "Not enough lines in config file" unless defined $_;
        chomp;        
        $self{$field} = $_;
    }

    while (defined(local $_ = <$in>)) {
        warn "Extra line '$_' in config file will be ignored" 
            unless $options{quiet};
    }
    
    return bless \%self, $class;
}

sub gene_annotation_file { shift->{gene_annotation_file} }
sub bowtie_bin { shift->{bowtie_bin} }
sub blat_bin { shift->{blat_bin} }
sub mdust_bin { shift->{mdust_bin} }
sub bowtie_genome_index { shift->{bowtie_genome_index} }
sub bowtie_gene_index { shift->{bowtie_gene_index} }
sub blat_genome_index { shift->{blat_genome_index} }

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

=item _missing_fields

Given a config hash, return a list of fields that are missing from it.

=back

=head1 AUTHOR

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012, University of Pennsylvania

=cut

sub missing_fields {
    my ($self) = @_;
    return grep { not $self->{$_} } @FIELDS;
}


1;
