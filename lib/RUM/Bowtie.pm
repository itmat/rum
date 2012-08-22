package RUM::Bowtie;

use strict;
use warnings;

use RUM::BinDeps;

use Carp;

sub read_bowtie_mapping_set {
    my ($fh) = @_;

    my @forward;
    my @reverse;

    my $want_order;

    my $pos = tell $fh;

  LINE: while (1) {
        my $line = <$fh>;
        last LINE unless defined $line;

        chomp $line;
        $line =~ /^seq.(\d+)(a|b)?/ 
        or croak "Unexpected line from bowtie output: $line\n";

        my ($order, $direction) = ($1, $2);

        if (!defined $want_order) {
            $want_order = $1;
            $pos = tell $fh;
        }
        elsif ($order == $want_order) {
            $pos = tell $fh;
        }
        else {
            seek $fh, $pos, 0;
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

sub run_bowtie {
    my (%params) = @_;

    my @missing;
    
    my $limit    = delete $params{limit};
    my $index = delete $params{index} or push @missing, 'index';
    my $reads     = delete $params{query} or push @missing, 'query';
    
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
               
    if ($limit) {
        push @cmd, '-k', $limit;
    }
    else {
        push @cmd, '-a';
    }

    my $cmd = join ' ', @cmd;
    warn "Command is $cmd\n";
    open my $bowtie_out, '-|', $cmd;
    return $bowtie_out;
}

1;
