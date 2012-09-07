package RUM::SystemCheck;

use strict;
use warnings;

use Carp;

use RUM::Logger;
use RUM::Common qw(format_large_int);
use RUM::Index;
use Text::Wrap qw(wrap fill);
my $log = RUM::Logging->get_logger;

sub check_ram {

    my (%params) = @_;

    my $c   = delete $params{config};
    my $say = delete $params{say} || sub { print @_ };

    return if $c->ram_ok || $c->ram;

    if (!$c->ram) {
        $say->("I'm going to try to figure out how much RAM ",
                   "you have. If you see some error messages here, ",
                   " don't worry, these are harmless.");
        my $available = available_ram(config => $c);
        $c->set('ram', $available);
    }

    my $index = RUM::Index->load($c->index_dir);

    my $genome_size = $index->genome_size;
    my $gs4 = &format_large_int($genome_size);
    my $gsz = $genome_size / 1000000000;
    my $min_ram = int($gsz * 1.67)+1;
    
    $say->();

    my $totalram = $c->ram;
    my $RAMperchunk;
    my $ram;

    my $num_chunks = $c->chunks || 1;
    
    # We couldn't figure out RAM, warn user.
    if ($totalram) {
        $RAMperchunk = $totalram / $num_chunks;
    } else {
        warn("Warning: I could not determine how much RAM you " ,
             "have.  If you have less than $min_ram gigs per ",
             "chunk this might not work. I'm going to ",
             "proceed with fingers crossed.\n");
        $ram = $min_ram;      
    }
    
    if ($totalram) {

        if($RAMperchunk >= $min_ram) {
            $say->(sprintf(
                "It seems like you have %.2f Gb of RAM on ".
                "your machine. Unless you have too much other stuff ".
                "running, RAM should not be a problem.", $totalram));
        } else {
            _prompt_not_enough_ram(
                total_ram     => $totalram,
                ram_per_chunk => $RAMperchunk,
                min_ram       => $min_ram,
                num_chunks    => $num_chunks);
        }
        $say->();
        $ram = $min_ram;
        if($ram < 6 && $ram < $RAMperchunk) {
            $ram = $RAMperchunk;
            if($ram > 6) {
                $ram = 6;
            }
        }

        $c->set('ram', $ram);
        $c->set('ram_ok', 1);

        $c->save;
        # sleep($PAUSE_TIME);
    }

}

sub available_ram {

    my (%params) = @_;

    my $c = delete $params{config} or croak "Need 'config' parameter'";

    return $c->ram if $c->ram;

    local $_;

    # this should work on linux
    $_ = `free -g 2>/dev/null`; 
    if (/Mem:\s+(\d+)/s) {
        return $1;
    }

    # this should work on freeBSD
    $_ = `grep memory /var/run/dmesg.boot 2>/dev/null`;
    if (/avail memory = (\d+)/) {
        return int($1 / 1000000000);
    }

    # this should work on a mac
    $_ = `top -l 1 | grep free`;
    if (/(\d+)(.)\s+used, (\d+)(.) free/) {
        my $used = $1;
        my $type1 = $2;
        my $free = $3;
        my $type2 = $4;
        if($type1 eq "K" || $type1 eq "k") {
            $used = int($used / 1000000);
        }
        if($type2 eq "K" || $type2 eq "k") {
            $free = int($free / 1000000);
        }
        if($type1 eq "M" || $type1 eq "m") {
            $used = int($used / 1000);
        }
        if($type2 eq "M" || $type2 eq "m") {
            $free = int($free / 1000);
        }
        return $used + $free;
    }
    return 0;
}

sub _prompt_not_enough_ram {
    my (%options) = @_;

    my $say           = delete $options{say} || sub { print @_ };
    my $min_ram       = delete $options{min_ram};
    my $num_chunks    = delete $options{num_chunks};
    my $ram_per_chunk = delete $options{ram_per_chunk};
    my $total_ram     = delete $options{total_ram};

    my $prompt = <<"EOF";
WARNING ***

Based on the size of your genome, this job will require about $min_ram
GB of RAM for each chunk. You seem to have about $total_ram GB of RAM,
or about $ram_per_chunk GB per chunk. If you run all $num_chunks
chunks at the same time on this machine, it may fail.  Do you still
want me to split the input into $num_chunks chunks?

y or n: 
EOF

    $prompt = fill('*** ', '*** ', $prompt);
    chomp $prompt;

    $log->info($prompt);

    $say->($prompt);

    my $response = <STDIN>;
    if ($response !~ /^y$/i) {
        $log->info("User responded to not-enough-memory prompt with " 
                   . "$response; exiting");
        exit;
    }
}

sub check_gamma {
    my (%params) = @_;

    my $config = delete $params{config} or croak "check_gamma needs a config";

    my $host = `hostname`;

    my $on_gamma = `hostname` =~ / (?: login | gamma) 
                                   \.genomics\.upenn\.edu/xm;

    my $running_locally = $config->platform eq 'Local';
    
    if ($on_gamma && $running_locally) {
        die("You cannot run RUM on the PGFI cluster "
            . "without using the --qsub option.\n");
    }
}


sub check_deps {

    local $_;
    my $deps = RUM::BinDeps->new;
    my @deps = ($deps->bowtie, $deps->blat, $deps->mdust);
    my @missing;
    for (@deps) {
        -x or push @missing, $_;
    }
    my $dependency_doesnt = @missing == 1 ? "dependency doesn't" : "dependencies don't";
    my $it = @missing == 1 ? "it" : "them";

    if (@missing) {
        die(
            "The following binary $dependency_doesnt exist:\n\n" .
            join("", map(" * $_\n", @missing)) .
            "\n" . 
            "Please install $it by running \"perl Makefile.PL\"\n");
    }
}

1;

__END__

=head1 NAME

RUM::SystemCheck - Functions for making sure the system we're running on is acceptable

=head1 METHODS

=over 4

=item check_ram(%params)

Attempt to make sure that the system has enough ram for this
job. Prompts the user if it does not. Takes these params:

=over 4

=item config

The RUM::Config for the job

=item say

A CODE ref that will be called with one string argument, and should
handle displaying that string to the user.

=back

=item available_ram(%params)

Return the amount of available ram in GB. Takes a 'config' param that
is the RUM::Config for the job.

=item check_gamma(%params)

Specific for PGFI cluster. Die if the user is trying to run a job on
the head node of the PGFI cluster without --qsub. Takes a 'config'
param that is the RUM::Config for the job.

=item check_deps()

Make sure I can find blat, bowtie, and mdust, and die if I can't.

=back
