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

our @EXPORT_OK = qw(@QUEUE report  satisfy_with_command chain);

use subs qw(action target satisfy rule children is_satisfied plan
            download report);

=item RUM::Rule->new(NAME, TARGET, ACTION, DEPS)

=cut

sub new {
    my ($class, $name, $products, $target, $action, $deps) = @_;
    $deps = [] unless defined $deps;
#    croak "First argument of Rule must be a name or a sub that returns a name" 
#        if ref($name) && ref($name) !~ /CODE/;
##    croak "Second argument of Rule must be a targetition test" 
 #       unless ref($target) =~ /CODE/;
 #   croak "Third argument of Rule must be a precondition" 
 #       unless ref($action) =~ /CODE/;
 #   croak "Fourth arg must be code or an array ref" 
 #       unless (ref($deps) =~ /CODE/ or ref($deps) =~ /ARRAY/);
    
    return bless {
        name => $name,
        products => $products,
        target => $target,
        action => $action,
        deps => $deps }, $class;
}

=back

=head3 RUM::Rule methods

=over 4

=item $rule->name()

Return the name of the rule.

=cut

sub name {
    my ($self, $engine, @args) = @_;;
    my $name = $self->{name};
    if (ref($name) =~ /CODE/) {
        return $name->($engine, @args);
    }                   
    return $name;
}

=item $rule->deps(OPTIONS, ARGS)

Return a list of the rules that must be run before this rule can be
run.

=cut

sub deps {
    my ($self, $engine, @args) = @_;
    my $deps = $self->{deps};
    return @{ $deps } if ref($deps) =~ /ARRAY/;
    return $deps->($engine, @args) if ref($deps) =~ /CODE/;
    return ($deps);
}

=item $rule->queue_deps()

Add the dependencies of this rule to the engine's queue.

=cut

sub queue_deps {
    my ($self, $engine, @args) = @_;
    DEBUG "Getting deps for $self->{name}\n";
    return undef if $self->{queued_deps}++;
    if (my @deps = $self->deps($engine, @args)) {
        DEBUG "My deps are @deps\n";
        push @{ $engine->queue}, $self;
        push @{ $engine->queue}, @deps;
        return 1;
    }
    return undef;
}

sub products {
    my ($self, $engine, @args) = @_;
    my $products = $self->{products};
    if (!$products ) {
        return ();
    }
    elsif (not ref($products)) {
        return ($products);
    }
    elsif (ref($products) =~ /ARRAY/) {
        return @{ $products };
    }
    elsif (ref($products) =~ /CODE/) {
        return $products->($engine, @args);
    }
}

=item $rule->is_satisfied()

Returns true if the RULE is already satisfied, false otherwise.

=cut

sub is_satisfied {
    my ($self, $engine, @args) = @_;
    my $target = $self->{target};
    if ($target) {
        return $target->($engine, @args);
    }
    else {
        return not grep { not -e $_ } $self->products($engine, @args);
    }

}

=back

return 1;

