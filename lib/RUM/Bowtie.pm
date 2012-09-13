package RUM::Bowtie;

use strict;
use warnings;
use autodie;

use RUM::BinDeps;

use Carp;

sub bowtie_mapping_set_reader {
    my ($fh) = @_;

    my $last;

    return sub {

        my @forward;
        my @reverse;
        
        my $want_order;
        
        my $pos = tell $fh;
        
      LINE: while (1) {
            my $line;
            if ($last) {
                $line = $last;
                undef $last;
            }
            else {
                $line = <$fh>;
            }
            last LINE unless defined $line;
            
            chomp $line;
            $line =~ /^seq.(\d+)(a|b)?/ 
            or croak "Unexpected line from bowtie output: $line\n";
            
            my ($order, $direction) = ($1, $2);
            
            if (!defined $want_order) {
                $want_order = $1;
            }
            elsif ($order == $want_order) {
                # Pass
            }
            else {
                $last = $line;
                last LINE;
            }
            
            my @fields = split /\t/, $line;
            my $rec = [ @fields, $order, $direction ];
            if ($direction eq 'b') {
                push @reverse, $line;
            }
            else {
                push @forward, $line;
            }
        }
        
        if (@forward || @reverse) {
            return (\@forward, \@reverse);
        }
        else {
            return;
        }
        
    }
}

sub run_bowtie {
    my (%params) = @_;

    my @missing;
    
    my $limit = delete $params{limit};
    my $index = delete $params{index} or push @missing, 'index';
    my $reads = delete $params{query} or push @missing, 'query';
    my $tee   = delete $params{tee};
    if (@missing) {
        croak "Missing required args " . join(', ', @missing);
    }

    my @cmd = (RUM::BinDeps->new->bowtie,
                '--best',
                '--strata',
                '-f', $index,
                $reads,
                '-v', 3,
                '--suppress', '6,7,8',
                '-p', 1,
                '--quiet');
               
    if (defined $limit) {
        push @cmd, '-k', $limit;
    }
    else {
        push @cmd, '-a';
    }

    my $cmd = join ' ', @cmd;
    if (defined $tee) {
        $cmd .= " | tee $tee";
    }

    open my $bowtie_out, '-|', $cmd;
    return $bowtie_out;
}

1;

=head1 NAME 

RUM::Bowtie - Interface to Bowtie

=head1 METHODS

=over 4

=item bowtie_mapping_set_reader

Return a CODE ref that, when called, will return the next set of
alignments from the given filehandle. Alignments for the same pair of
reads will be grouped together. The resulting CODE ref returns results
as a list of one or two array refs. If there are only forward reads,
it returns a a list of one array ref, containing the forward
mappings. If there are reverse reads, it returns a list of two array
refs, one for the forward reads and one for the reverse.

=item run_bowtie

Run Bowtie and return a filehandle that contains the results. Accepts
the following params:

=over 4

=item limit

Maximum number of non-unique mappings to report for each read.

=item index

The path to the bowtie index to use.

=item query

The reads file.

=item tee

If defined, I'll also write the output to this file, in addition to
streaming it through the returned filehandle.

=back

=back


