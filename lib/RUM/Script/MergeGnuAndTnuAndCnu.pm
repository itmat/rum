package RUM::Script::MergeGnuAndTnuAndCnu;

no warnings;

use RUM::Logging;

our $log = RUM::Logging->get_logger();

use base 'RUM::Script::Base';

sub summary {
    'Merge the GNU, TNU, and CNU files'
}

sub accepted_options {
    return (
        RUM::Property->new(
            opt => 'gnu-in=s',
            required => 1,
            desc => 'File of non-unique genome mappers'),
        RUM::Property->new(
            opt => 'tnu-in=s',
            required => 1,
            desc => 'File of non-unique transcriptome mappers'),
        RUM::Property->new(
            opt => 'cnu-in=s',
            required => 1,
            desc => 'File of consistent non-unique mappers'),
        RUM::Property->new(
            opt => 'output=s',
            desc => 'Merged output file',
            required => 1)
    );
}

sub run {
    my ($self) = @_;
    my $props = $self->properties;
    my $infile1 = $props->get('gnu_in');
    my $infile2 = $props->get('tnu_in');
    my $infile3 = $props->get('cnu_in');
    my $outfile = $props->get('output');

    open INFILE1, "<", $infile1;
    open INFILE2, "<", $infile2;
    open INFILE3, "<", $infile3;

    $x1 = `tail -1 $infile1`;
    $x2 = `tail -1 $infile2`;
    $x3 = `tail -1 $infile3`;
    $x1 =~ /seq.(\d+)[^\d]/;
    $n1 = $1;
    $x2 =~ /seq.(\d+)[^\d]/;
    $n2 = $1;
    $x3 =~ /seq.(\d+)[^\d]/;
    $n3 = $1;
    $M = $n1;
    if ($n2 > $M) {
        $M = $n2;
    }
    if ($n3 > $M) {
        $M = $n3;
    }
    $line1 = <INFILE1>;
    $line2 = <INFILE2>;
    $line3 = <INFILE3>;
    chomp($line1);
    chomp($line2);
    chomp($line3);

    open(OUTFILE, ">", $outfile) or die "Can't open $outfile for writing: $!";

    for ($s=1; $s<=$M; $s++) {
        undef %hash;
        $line1 =~ /seq.(\d+)([^\d])/;
        $n = $1;
        $type = $2;
        while ($n == $s) {
            if ($type eq "\t") {
                $hash{$line1}++;
            } else {
                $line1b = <INFILE1>;
                chomp($line1b);
                if ($line1b eq '') {
                    last;
                }
                $hash{"$line1\n$line1b"}++;
            }
            $line1 = <INFILE1>;
            chomp($line1);
            if ($line1 eq '') {
                last;
            }
            $line1 =~ /seq.(\d+)([^\d])/;
            $n = $1;
            $type = $2;
        }
        $line2 =~ /seq.(\d+)([^\d])/;
        $n = $1;
        $type = $2;
        while ($n == $s) {
            if ($type eq "\t") {
                $hash{$line2}++;
            } else {
                $line2b = <INFILE2>;
                chomp($line2b);
                if ($line2b eq '') {
                    last;
                }
                $hash{"$line2\n$line2b"}++;
            }
            $line2 = <INFILE2>;
            chomp($line2);
            if ($line2 eq '') {
                last;
            }
            $line2 =~ /seq.(\d+)([^\d])/;
            $n = $1;
            $type = $2;
        }
        $line3 =~ /seq.(\d+)([^\d])/;
        $n = $1;
        $type = $2;
        while ($n == $s) {
            if ($type eq "\t") {
                $hash{$line3}++;
            } else {
                $line3b = <INFILE3>;
                chomp($line3b);
                if ($line3b eq '') {
                    last;
                }
                $hash{"$line3\n$line3b"}++;
            }
            $line3 = <INFILE3>;
            chomp($line3);
            if ($line3 eq '') {
                last;
            }
            $line3 =~ /seq.(\d+)([^\d])/;
            $n = $1;
            $type = $2;
        }
        for $key (keys %hash) {
            if ($key =~ /\S/) {
                print OUTFILE "$key\n";
            }
        }
    }

    close(INFILE1);
    close(INFILE2);
    close(INFILE3);
}
