package RUM::Rule::Engine;

=head1 NAME

RUM::Rule - Rule and dependency framework

=head1 DESCRIPTION

This is a rule engine, somewhat like GNU make but in Perl. You can use
it to tie together tasks that are dependent on each other. If you ask
it to run a task, it will only run the other tasks that the main goal
depends on. It will only run tasks that produce files if those files
don't already exists. The intent is that this can be used to simplify
the interaction between scripts that depend on output produced by
other scripts. Please see t/09-integration.it for an example of its
usage.

=cut

use strict;
use warnings;
use Carp;

use FindBin qw($Bin);

use Exporter 'import';
use File::Path qw(mkpath rmtree);
use Log::Log4perl qw(:easy);

our @EXPORT_OK = qw(report satisfy_with_command chain);
use RUM::Rule;

use subs qw(report);

=head2 Constructors

=over 4

=item new(OPTIONS)

Create a new RUM::Rule::Engine with the given options:

=over 4

=item B<dry_run>

Indicate that this engine should only do dry runs, and not actually
execute actions.

=item B<verbose>

Indicate that this engine should print verbose output.

=back

=cut

sub new {
    my ($class, %options) = @_;
    my $dry_run = delete $options{dry_run};
    my $verbose = delete $options{verbose};
    my @extra = keys %options;
    warn "Extra keys in RUM::Rule::Engine constructor: @extra" if @extra;
    return bless {
        dry_run => $dry_run,
        verbose => $verbose,
        queue => [],
        rules => []
    }
}

=back

=head2 Methods

=over 4

=item verbose([FLAG])

With out FLAG, just returns whether this engine is verbose; with flag,
sets the verbose flag.

=cut

sub verbose { 
    my ($self, $flag) = @_;
    $self->{verbose} = $flag if defined($flag);
    return $self->{verbose};
}

=item dry_run([FLAG])

Without FLAG, just returns whether this engine will do a dry run (as
opposed to actually running tasks); with flag, sets the dry_run flag.

=cut

sub dry_run { 
    my ($self, $flag) = @_;
    $self->{dry_run} = $flag if defined($flag);
    return $self->{dry_run};
    $_[0]->{dry_run} 
}

=item queue

Returns the work queue for this engine.

=cut

sub queue { $_[0]->{queue} }

=item rule OPTIONS

Add a rule to this engine and return it. The options are:

=over 4

=item B<name>

Either the name of the rule as a string or a code ref that will return
the name. It will be called with the engine and whatever extra
arguments are passed to I<build()>.

=item B<targets>

A code ref that returns true when the rule is satisfied. It will be
called with the engine and whatever extra arguments are passed to
I<build()>.

=item B<action>

A code ref that can be called to satisfy the rule. It will be called
with the engine and whatever extra arguments are passed to I<build()>.

=item B<depends_on>

Either:

=over 4

=item *

an ref to an array of rules that must be run before this rule
can be run

=item *

the name of a target that should be produced by another rule

=item *

a ref to an array of named targets that should be produced by other rules

=item *

a code ref that will return one of the types described above. It will
be called with the engine and whatever arguments are passed to
I<build()>.

=back

=back

=cut

sub rule {
    my ($self, @args) = @_;
    croak "Odd number of options to rule" unless @args % 2 == 0;
    my (%options) = @args;
    my $rule = new RUM::Rule($options{name} || "",
                             $options{produces} || [],
                             $options{target},
                             $options{action} || sub { },
                             $options{depends_on} || [ ]);
    push @{ $self->{rules} }, $rule;
    return $rule;
}

=item build ARGS

Build any rules currently in the @QUEUE. ARGS can be any extra
arguments, and will be paseed to all of the Rule methods that are
called as part of this build. This is a good way to parameterize a set
of rules.

=cut

sub build {
    my ($self, @args) = @_;
    my $last_rule;
  RULE: while (@{ $self->queue }) {
        my $rule = pop @{ $self->queue };


        if (not ref $rule) {
            my @rules;
            for my $other (@{ $self->{rules} }) {
                my @products = $other->products($self, @args);
                for my $product (@products) {
                    warn "Rule ". $other->name . " gave an undefined product; ".
                        "its products are @products"
                        unless defined($product);
                    
                    push @rules, $other if $product eq $rule;
                }
            }
            croak "I can't find a rule to produce $rule" unless @rules;
            $rule = $rules[0];
        }

        next RULE if $rule eq $last_rule;

        $last_rule = $rule;

        croak "I can't find a rule to produce $rule" unless $rule;
        my $name = $rule->name($self, @args);
        DEBUG "Looking at rule $name\n";
        if ($rule->queue_deps($self, @args)) {
            DEBUG "Queued deps for $name\n";
        }
        
        else {
            DEBUG "Doing work for $name\n";
            my $name = $rule->name($self, @args);
            if ($rule->is_satisfied($self, @args)) {
                report "Rule '$name' is satisfied" if $self->verbose;
            }
            else {
                report $name;
                report "I should get " . join(", ", $rule->products($self, @args)) if $self->verbose;
                $rule->{action}->($self, @args);
            }
        }
    }
}

=item enqueue RULES

Add all the given RULES to the back of the queue in order.

=cut

sub enqueue {
    my $self = shift();
    while (my $rule = shift()) {
        unshift @{ $self->queue }, $rule;
    }
}

=back

=head3 Canned actions

Each of these subs return an anonymous sub that can be used as an
action in a call to rule().

=over 4

=cut

=item satisfy_with_command CMD

Returns a sub that when called with a true argument executes CMD, and
when called with a false argument just prints the cmd.

=cut

sub satisfy_with_command {
    my @cmd = @_;
    return sub {
        my ($rules) = @_;
        if ($rules->dry_run) {
            print "@cmd\n";
        }
        else {
            system(@cmd) == 0 or croak "Can't execute @cmd: $!";
        }
    }
}

=item chain ACTIONS

Chain together some actions: return an action that when executed
simply executes all of the given ACTIONs in order.

=cut

sub chain {
    my @actions = @_;
    return sub {
        my @args = @_;
        for my $action (@actions) {
            $action->(@args);
        }
    }
}

=back

=head3 Canned Rules

=over 4

=item download_rule REMOTE, LOCAL

A rule that does nothing if LOCAL exists, otherwise downloads a file
identified by REMOTE and saves it to LOCAL.

=cut

sub download_rule {
    my ($self, $url, $local, %options) = @_;
    $options{name}   ||= "Download $url to $local";
    $options{produces} ||= $local;
    $options{action} ||= sub {
        my $ua = LWP::UserAgent->new;
        $ua->get($url, ":content_file" => $local);
    };
    return $self->rule(%options);
}

=item rmtree_rule PATH

A rule that removes an entire directory tree if it exists. I<USE WITH
CAUTION!!!>

=cut

sub rmtree_rule {
    my ($self, $path) = @_;
    return $self->rule(
        name => "Remove $path",
        target => sub { not -d $path },
        action => sub { 
            my ($rules) = @_;
            if ($rules->dry_run) {
                print "rm -rf $path";
            }
            else {
                rmtree($path);
            }
        });
}

=item report ARGS

Print ARGS as a message prefixed with a "#" character.

=cut

sub report {
    my @args = @_;
    print "# @args\n";
}

=item make_paths PATHS

Make any of the PATHS that don't already exist.

=cut

sub make_paths {
    my ($self, @paths) = @_;
    for my $path (@paths) {
        if ($self->dry_run) {
            print "mkdir -p $path\n";
        }
        else {
            mkpath($path) unless -e $path;
        }
    }
}




return 1;
