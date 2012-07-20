package RUM::Script::MakeUnmappedFile;

use strict;
use warnings;
use autodie;

use RUM::SeqIO;
use RUM::Usage;
use RUM::RUMIO;

use base 'RUM::Script::Base';

# FIX THIS SO THAT READS CAN SPAN MORE THAN ONE LINE IN THE FASTA FILE

sub main {

    my $self = __PACKAGE__->new;

    $self->get_options(
        "reads-in=s"      => \(my $reads_filename),
        "unique-in=s"     => \(my $bowtie_unique_filename),
        "non-unique-in=s" => \(my $bowtie_nu_filename),
        "output|o=s"      => \(my $out_filename),
        "single"          => \(my $single),
        "paired"          => \(my $paired));
    
    # Check command line args
    $reads_filename or RUM::Usage->bad(
        "Please provide a reads file with --reads-in");
    $bowtie_unique_filename or RUM::Usage->bad(
        "Please provide a unique mapper file with --unique-in");
    $bowtie_nu_filename or RUM::Usage->bad(
        "Please provide a non-unique mapper file with --non-unique-in");
    $out_filename or RUM::Usage->bad(
        "Please specify an output file with --output or -o");
    ($paired xor $single) or RUM::Usage->bad(
        "Please specify exactly one of --paired or --single");

    open my $out_fh, ">", $out_filename;
    my $unique    = RUM::RUMIO->new(-file => $bowtie_unique_filename);
    my $nu        = RUM::RUMIO->new(-file => $bowtie_nu_filename);
    my $reads_in  = RUM::SeqIO->new(-file => $reads_filename);
    my $reads_out = RUM::SeqIO->new(-fh => $out_fh);

    my (%unique_counts, %nu_counts);

    $self->logger->debug("Reading unique mappers");
    while (my $aln = $unique->next_aln) {
        my $id = $aln->readid_directionless;
        $unique_counts{$id}++ if $aln->contains_forward;
        $unique_counts{$id}++ if $aln->contains_reverse;
    }

    $self->logger->debug("Reading non-unique mappers");
    while (my $aln = $nu->next_aln) {
        $nu_counts{$aln->readid_directionless}++;
    }

    $self->logger->debug("Filtering mapped reads");

    my $threshold = $paired ? 1 : 0;

    while (my $seq = $reads_in->next_seq) {
        my $id = $seq->readid_directionless;
        if (($unique_counts{$id} || 0) <= $threshold && ! $nu_counts{$id}) {
            $reads_out->write_seq($seq);
        }

    }
    return 0;
}

1;

__END__

=head1 NAME

RUM::Script::MakeUnmappedFile

=head1 METHODS

=over 4

=item RUM::Script::MakeUnmappedFile->main

Run the script.

=back

=head1 AUTHORS

Gregory Grant (ggrant@grant.org)

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012, University of Pennsylvania



