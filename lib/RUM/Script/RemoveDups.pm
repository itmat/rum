package RUM::Script::RemoveDups;

use strict;
use warnings;
use autodie;

use RUM::Usage;
use RUM::RUMIO;

use base 'RUM::Script::Base';

sub main {

    my $self = __PACKAGE__->new;
    $self->get_options(
        "non-unique-out=s" => \(my $outfile),
        "unique-out=s"     => \(my $outfileu));

    my $infile = $ARGV[0] or RUM::Usage->bad(
        "Please provide an input file of non-unique mappers");
    $outfile or RUM::Usage->bad(
        "Specify an output file for non-unique mappers with --non-unique-out");
    $outfileu or RUM::Usage->bad(
        "Specify an output file for unique mappers with --unique-out");

    open my $in_fh,       "<", $infile;
    open my $out_nu,      ">", $outfile;
    open my $out_unique, ">>", $outfileu; 

    my $iter = RUM::RUMIO->new(-fh => $in_fh)->aln_iterator->group_by(
        sub { 
            $_[0]->readid_directionless eq 
            $_[1]->readid_directionless
        }
    );

    while (my $alns = $iter->next_val) {
        
        my %data;

        my $pairs = $alns->group_by(\&RUM::Identifiable::is_mate);

        while (my $pair = $pairs->next_val) {
            my $key = "";
            while (my $aln = $pair->next_val) {
                $key .= $aln->raw . "\n";
            }
            $data{$key} = 1;
        }

        my $out = keys %data == 1 ? $out_unique : $out_nu;

        for my $k (keys %data) {
            print $out $k;
        }
    }
}

1;

__END__

=head1 NAME

RUM::Script::RemoveDups - Separate an input RUM file into unique and non-unique mappers

=head1 METHODS

=over 4

=item RUM::Script::RemoveDups->main

Run the script.

=back

=head1 AUTHORS

Gregory Grant (ggrant@grant.org)

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012, University of Pennsylvania



