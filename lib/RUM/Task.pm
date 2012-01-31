package RUM::Task;

use strict;
use warnings;
use Carp;

use FindBin qw($Bin);
use lib "$Bin/..";

use RUM::Config qw(parse_organisms format_config);
use subs qw(satisfied_when satisfy task children is_satisfied plan download report);

our $FOR_REAL = 1;

my $mouse_config_file_name = "test-data/rum.config_mm9";
my $TEST_INDEX_DIR  = "test-data/indexes";
my $TEST_BIN_DIR    = "";
my $TEST_SCRIPT_DIR = "orig/scripts";
my $TEST_LIB_DIR    = "orig/lib";

sub report {
    my @args = @_;
    print "# @args\n";
}


=item satisfied_when CODE

Marker for a sub that should return true when the task is considered
satisfied and false otherwise.

=cut

sub satisfied_when (&) {
    return $_[0];
}

=item satisfy CODE

Marker for a sub that should be called to satisfy a task, assuming all
of its dependencies are satisfied.

=cut

sub satisfy (&) {
    return $_[0];
}


=item shell CMD

Execute cmd with system and croak if it fails.

=cut

sub shell {
    my @cmd = @_;
    system(@cmd) == 0 or croak "Can't execute @cmd: $!";
}


=item task NAME, IS_SATISFIED, SATISFY, DEPS

Return a task hash ref.

=over 4

=item NAME

A string that describes the task.

=item IS_SATISFIED

A code ref that takes no arguments and returns true when the task is satisfied.

=item SATISFY

A code ref that can be called to satisfy the task. It is called with
one arg; a true value indicates that it should actually do the work,
while a false value indicates that it should only report on what work
it would do (think "make -n").

=item DEPS

An iterator over the dependencies of this task.

=back

=cut

sub task {
    my ($name, $is_satisfied, $satisfy, $deps) = @_;
    croak "First arg must be name" if ref $name;
    croak "Second arg must be code" unless ref($is_satisfied) =~ /CODE/;
    croak "Third arg must be code" unless ref($satisfy) =~ /CODE/;
    
    $deps = sub { } unless defined $deps;
    croak "Fourth arg must be code" unless ref($deps) =~ /CODE/;
    return {
        name => $name,
        satisfied_when => $is_satisfied,
        satisfy => $satisfy,
        deps => $deps };
}


=item is_satisfied TASK

Returns true if the TASK is already satisfied, false otherwise.

=cut

sub is_satisfied {
    return $_[0]->{satisfied_when}->();
}

=item satisfy_with_command CMD

Returns a sub that when called with a true argument executes CMD, and
when called with a false argument just prints the cmd.

=cut

sub satisfy_with_command {
    my @cmd = @_;
    return sub {
        my ($forreal) = @_;
        if ($forreal) {
            return shell(@cmd);
        }
        else {
            report "@cmd\n";
        }
    }
}

sub iterator { 
    my @queue = @_;
    return sub {
        return shift(@queue);
    }
}

sub depends_on {
    my @deps = @_;
    return iterator(@deps);
}

sub download {
    my ($remote, $local) = @_;
    return task(
        "Download $local to $remote",
        satisfied_when { -f $local },
        satisfy_with_command("scp", $remote, $local));
}

sub copy_file {
    my ($src, $dst, $deps) = @_;
    return task(
        "Copy $src to $dst",
        satisfied_when { -f $dst },
        satisfy_with_command("cp", $src, $dst),
        $deps);
}

sub build {
    my ($goal) = @_;
    
    my @queue = ($goal);

    while (@queue) {
        my $task = pop(@queue);
        print "Looking at task $task->{name}\n";
        if (my $pre = $task->{deps}->()) {
            push(@queue, $task);
            push(@queue, $pre);
        }
        else {
            if (is_satisfied($task)) {
                report "Task '$task->{name}' is satisfied";
            }
            else {
                report "Building task '$task->{name}'";
                $task->{satisfy}->($FOR_REAL);
            }
        }
    }
    
}


sub ftp_rule {
    my ($remote, $local) = @_;
    return task(
        "Download $remote to $local",
        satisfied_when { -f "organisms.txt" },
        satisfy_with_command("ftp", "-o", $local, $remote));
}

sub chain {
    my @subs = @_;
    return sub {
        my @args = @_;
        for my $sub (@subs) {
            $sub->(@args);
        }
    }
}

sub get_download_indexes_task {

    my @organisms;

    my $download_organisims_txt = ftp_rule(
        "http://itmat.rum.s3.amazonaws.com/organisms.txt",
        "organisms.txt");

    my $parse_organisms = task(
        "Parse organisms file",
        satisfied_when { @organisms },
        satisfy {
            report "Parsing organisms file";
            open my $orgs, "<", "organisms.txt";
            @organisms = parse_organisms($orgs);
            for my $org (@organisms) {
                report "  got $org->{common}";
            }
        },
        depends_on($download_organisims_txt));

    my $returned_parse_organisms = 0;
    my $initialized_queue;
    my @queue;
    my $download_indexes = task(
        "Download indexes",
        satisfied_when { 1 },
        satisfy { },
        sub {
            if (!$returned_parse_organisms++) {
                return $parse_organisms;
            }
            
            elsif (@organisms) {
                unless ($initialized_queue++) {
                    for my $org (@organisms) {
                        if ($org->{common} eq "mouse") {
                            for my $url (@{ $org->{files} }) {
                                my $file = $TEST_INDEX_DIR . "/" .
                                    substr($url, rindex($url, "/") + 1);
                                print "Got a file: $file\n";
                                if ($file =~ /^(.*)\.gz$/) {
                                    my $unzipped = $1;
                                    push @queue, task(
                                        "Download and unzip $file",
                                        satisfied_when { 
                                            print "Looking for $unzipped\n";
                                            -f $unzipped },
                                        chain(
                                            satisfy_with_command("ftp", "-o", $file, $url),
                                            satisfy_with_command("gunzip", $file)));
                                }
                                else {
                                    push @queue, ftp_rule($url, $file);
                                }
                            }
                        }
                    }
                }

                return shift @queue;
            }

            croak "I can't find my dependencies until the orgs file is downloaded";
        });
    return $download_indexes;
}

my $make_config = task(
    "Make config file",
    satisfied_when { -f $mouse_config_file_name },
    satisfy {
        open my $out, ">", $mouse_config_file_name;
        my $config = format_config(
            "gene-annotation-file" => "$TEST_INDEX_DIR/mm9_refseq_ucsc_vega_gene_info.txt",
            "bowtie-bin" => "bowtie",
            "blat-bin"   => "blat",
            "mdust-bin"  => "mdust",
            "bowtie-genome-index" => "$TEST_INDEX_DIR/mm9_genome",
            "bowtie-gene-index" => "$TEST_INDEX_DIR/mm9_genes",
            "blat-genome-index" => "$TEST_INDEX_DIR/mm9_genome_one-line-seqs.fa",
            "script-dir" => $TEST_SCRIPT_DIR,
            "lib-dir" => $TEST_LIB_DIR);
        print $out $config;
    });


build $make_config;
build get_download_indexes_task();
