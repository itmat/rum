package RUM::Rule;

=head1 NAME

RUM::Rule

=head1 DESCRIPTION

You probably don't want to use this package directly. Please see
L<RUM:Rule::Engine>.

=head2 Methods

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

=item RUM::Rule->new(NAME, PRODUCTS, TARGET, ACTION, DEPS)

=cut

sub new {
    my ($class, $name, $products, $target, $action, $deps) = @_;
    $deps = [] unless defined $deps;
    
    return bless {
        name => $name,
        products => $products,
        target => $target,
        action => $action,
        deps => $deps }, $class;
}

=back

=head3 Methods

=over 4

=item $rule->name(ENGINE, ARGS)

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

=item $rule->deps(ENGINE, ARGS)

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

=item $rule->queue_deps(ENGINE, ARGS)

Add the dependencies of this rule to the engine's queue.

=cut

sub queue_deps {
    my ($self, $engine, @args) = @_;
    DEBUG "Getting deps for $self->{name}\n";
    return undef if $self->{queued_deps}++;
    if (my @deps = $self->deps($engine, @args)) {
        push @{ $engine->queue}, $self;
        push @{ $engine->queue}, @deps;
        return 1;
    }
    return undef;
}

=item $rule->products(ENGINE, ARGS)

Return a list of targets that this rule produces.

=cut

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

