package RUM::BaseIO;

use strict;
use warnings;
use autodie;

use Carp;

use RUM::Iterator;

sub new {

    my ($class, %options) = @_;

    my $file  = delete $options{-file};
    my $fh    = delete $options{-fh};
    my $table = delete $options{-table};

    unless (($file xor $fh) xor $table) {
        croak "$class->new needs exactly one of -file, -fh, or -table";
    }
    
    if ($table) {
        $fh = __PACKAGE__->table_to_tab_file($table);
    }

    open $fh, "<", $file unless $fh;
    my $self = {};
    $self->{file} = $file;
    $self->{fh} = $fh;
    return bless $self, $class;
}

sub aln_iterator {
    my ($self) = @_;
    return RUM::Iterator->new(sub { $self->next_aln });
}

sub table_to_tab_file {
    my ($class, $table) = @_;
    my $str = "";
    for my $row (@$table) {
        $str .= join("\t", @$row) . "\n";
    }
    open my $fh, "<", \$str;
    return $fh;
}

1;
