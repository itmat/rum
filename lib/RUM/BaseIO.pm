package RUM::BaseIO;

use strict;
use warnings;
use autodie;

use Carp;

use base 'RUM::Iterator';

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

    if ( ! $fh ) {
        open $fh, "<", $file;
    }

    my $self = $class->SUPER::new;

    $self->{filehandle} = $fh;
    $self->{filename}   = $file;
    return $self;
}

sub next_val {
    shift->next_rec;
}

sub filehandle { $_[0]->{"filehandle"} }

sub filename { $_[0]->{"filename"} }

sub aln_iterator { $_[0] }

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
