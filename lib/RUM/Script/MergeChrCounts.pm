package RUM::Script::MergeChrCounts;

use strict;
no warnings;

use RUM::Usage;
use RUM::Sort qw(by_chromosome);

use base 'RUM::Script::Base';

sub main {
    my $self = __PACKAGE__->new;

    $self->get_options(
        "output|o=s" => \(my $outfile));

    $outfile or RUM::Usage->bad(
        "Please specify an output file with --output or -o");
    
    my @file = @ARGV;
    
    @file > 0 or RUM::Usage->bad(
        "Please list the input files on the command line");
    
    open(OUTFILE, ">>", $outfile) or die "Can't open $outfile for appending";
    
    my %chrcnt;
    for my $filename (@file) {
        open(INFILE, $filename) or die "Can't open $filename for reading: $!";
        local $_ = <INFILE>;
        $_ = <INFILE>;
        $_ = <INFILE>;
        $_ = <INFILE>;
        while (defined ($_ = <INFILE>)) {
            chomp;
            my @a1 = split /\t/;
            $chrcnt{$a1[0]} = $chrcnt{$a1[0]} + $a1[1];
        }
        close(INFILE);
    }
    
    for my $chr (sort by_chromosome keys %chrcnt) {
        my $cnt = $chrcnt{$chr};
        print OUTFILE "$chr\t$cnt\n";
    }
    
    
}

1;

__END__

=head1 NAME

RUM::Script::MergeChrCounts

=head1 METHODS

=over 4

=item RUM::Script::MergeChrCounts->main

Run the script.

=back

=head1 AUTHORS

Gregory Grant (ggrant@grant.org)

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012, University of Pennsylvania



