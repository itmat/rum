package RUM::Rule::Engine;

=head1 NAME

RUM::Rule - Rule and dependency framework

=head1 DESCRIPTION

=head2 Subroutines

=over 4

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
        rules => [],
        file_rules => {},
    }
}

sub verbose { 
    my ($self, $flag);
    $self->{verbose} = $flag if defined($flag);
    return $self->{verbose};
}

sub dry_run { 
    my ($self, $flag) = @_;
    $self->{dry_run} = $flag if defined($flag);
    return $self->{dry_run};
    $_[0]->{dry_run} 
}

sub queue { $_[0]->{queue} }

=item rule OPTIONS

Return a rule object. Options are:

=over 4

=item name

Either the name of the rule as a string or a code ref that will return
the name. It will be called with whatever arguments are passed to
I<build()>.

=item TARGET

A code ref that returns true when the rule is satisfied. It will be
called with whatever arguments are passed to I<build()>.

=item ACTION

A code ref that can be called to satisfy the rule. It will be called
with whatever arguments are passed to I<build()>.

=item DEPS

Either an ref to an array of rules that must be run before this rule
can be run, or a code ref that will return such a list when called. If
it's a code ref, it will be called with whatever arguments are passed
to I<build()>.

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

=item build FOR_REAL, VERBOSE

Build any rules currently in the @QUEUE. If FOR_REAL is a true value,
actually run the rules; otherwise just print out some diagnostic
information. If VERBOSE is true, print out extra information.

=cut

sub build {
    my ($self, @args) = @_;

    while (@{ $self->queue }) {
        my $rule = pop @{ $self->queue };
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
                report "Building rule '$name'";
                $rule->{action}->($self, @args);
            }
        }
    }
}

=item enqueue RULES

Add all the given RULES to the queue in order.

=cut

sub enqueue {
    my $self = shift();
    while (my $rule = shift()) {
        unshift @{ $self->queue }, $rule;
    }
}

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

=item make_path_rule PATH

A rule that creates a path on the filesystem if it doesn't already exist.

=cut

sub make_path_rule {
    my ($self, $path) = @_;
    return $self->rule(
        name => "Make path $path",
        produces => $path,
        action => sub { 
            if ($_[0]) {
                mkpath($path);
            }
            else {
                print "mkdir -p $path\n";
            }
        });
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


return 1;
