package RUM::Rule;

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
use LWP::UserAgent;

our @EXPORT_OK = qw(@QUEUE report make_path_rule target action rule download_rule 
                    satisfy_with_command build chain enqueue rule);

use subs qw(action target satisfy rule children is_satisfied plan
            download report);

our @QUEUE;

=item RUM::Rule->new(NAME, TARGET, ACTION, DEPS)

=cut

sub new {
    my ($class, $name, $target, $action, $deps) = @_;
    $deps = [] unless defined $deps;
#    croak "First argument of Rule must be a name" 
#        if ref($name) ;
    croak "Second argument of Rule must be a targetition test" 
        unless ref($target) =~ /CODE/;
    croak "Third argument of Rule must be a precondition" 
        unless ref($action) =~ /CODE/;
    croak "Fourth arg must be code or an array ref" 
        unless (ref($deps) =~ /CODE/ or ref($deps) =~ /ARRAY/);
    
    return bless {
        name => $name,
        target => $target,
        action => $action,
        deps => $deps }, $class;
}



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
    my (@args) = @_;
    croak "Odd number of options to rule" unless @args % 2 == 0;
    my (%options) = @_;
    return new RUM::Rule($options{name} || "",
                         $options{target} || sub { undef },
                         $options{action} || sub { },
                         $options{depends_on} || [ ]);
}

=back

=head3 RUM::Rule methods

=over 4

=item $rule->name()

Return the name of the rule.

=cut

sub name {
    my ($self, $options, @args) = @_;;
    my $name = $self->{name};
    if (ref($name) =~ /CODE/) {
        return $name->($options, @args);
    }
    return $name;
}

=item $rule->deps(OPTIONS, ARGS)

Return a list of the rules that must be run before this rule can be
run.

=cut

sub deps {
    my ($self, $options, @args) = @_;
    my $deps = $self->{deps};
    return @{ $deps } if ref($deps) =~ /ARRAY/;
    return @{ $deps->($options, @args) };
}

=item $rule->queue_deps()

Add the dependencies of this rule to the @QUEUE.

=cut

sub queue_deps {
    my ($self, $options, @args) = @_;
    DEBUG "Getting deps for $self->{name}\n";
    return undef if $self->{queued_deps}++;
    if (my @deps = $self->deps($options, @args)) {
        DEBUG "My deps are @deps\n";
        push @QUEUE, $self;
        push @QUEUE, @deps;
        return 1;
    }
    return undef;
}

=item $rule->is_satisfied()

Returns true if the RULE is already satisfied, false otherwise.

=cut

sub is_satisfied {
    my ($self, $options, @args) = @_;
    return $self->{target}->($options, @args);
}

=item report ARGS

Print ARGS as a message prefixed with a "#" character.

=cut

sub report {
    my @args = @_;
    print "# @args\n";
}

=item target CODE

Marker for a sub that should return true when the rule is considered
satisfied and false otherwise.

=cut

sub target (&) {
    return $_[0];
}

=item action CODE

Marker for a sub that should be called to satisfy a rule, assuming all
of its dependencies are satisfied.

=cut

sub action (&) {
    return $_[0];
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
        my ($options) = @_;
        if ($options->{dry_run}) {
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
    my ($url, $local, %options) = @_;
    $options{name}   ||= "Download $url to $local";
    $options{target} ||= sub { -f $local };
    $options{action} ||= sub {
        my $ua = LWP::UserAgent->new;
        $ua->get($url, ":content_file" => $local);
    };
    return rule(%options);
}

=item make_path_rule PATH

A rule that creates a path on the filesystem if it doesn't already exist.

=cut

sub make_path_rule {
    my ($path) = @_;
    return rule(
        name => "Make path $path",
        target => sub { -d $path },
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
    my ($path) = @_;
    return rule(
        name => "Remove $path",
        target => sub { not -d $path },
        action => sub { 
            my ($options) = @_;
            if ($options->{dry_run}) {
                print "rm -rf $path";
            }
            else {
                rmtree($path);
            }
        });
}

=item build FOR_REAL, VERBOSE

Build any rules currently in the @QUEUE. If FOR_REAL is a true value,
actually run the rules; otherwise just print out some diagnostic
information. If VERBOSE is true, print out extra information.

=cut

sub build {
    my ($options, @args) = @_;

    while (@QUEUE) {
        my $rule = pop @QUEUE;
        my $name = $rule->name($options, @args);
        DEBUG "Looking at rule $name\n";
        if ($rule->queue_deps($options, @args)) {
            DEBUG "Queued deps for $name\n";
        }
        
        else {
            DEBUG "Doing work for $name\n";
            my $name = $rule->name($options, @args);
            if ($rule->is_satisfied($options, @args)) {
                report "Rule '$name' is satisfied" if $options->{verbose};
            }
            else {
                report "Building rule '$name'";
                $rule->{action}->($options, @args);
            }
        }
    }
}

=item enqueue RULES

Add all the given RULES to the queue in order.

=cut

sub enqueue {
    while (my $rule = shift()) {
        unshift @QUEUE, $rule;
    }
}


return 1;

