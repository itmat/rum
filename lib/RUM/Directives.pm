package RUM::Directives;

use strict;
use warnings;

use Carp;

our $AUTOLOAD;

# At most one of these directives may be specified, and the presence
# of one of them will prevent us from running any part of the
# pipeline.
our @ACTIONS = qw(
    version
    help
    help_config
    save
    diagram
    status
    clean
    veryclean
    shell_script
);

# This are just boolean flags that modify the behavior of the
# actions.
our @MODIFIERS = qw(
    quiet
    child
    dry_run
    preprocess
    process
    postprocess
    all
);

sub new {
    my ($class) = @_;
    my %self = map { ($_ => undef) } (@ACTIONS, @MODIFIERS);
    $self{all} = 1;
    bless \%self, $class;
}

sub run {
    my ($self, $phase) = @_;
    my @actions = grep { $self->{$_} } @ACTIONS;
    return !@actions;
}

sub AUTOLOAD {
    my $self = shift;
    
    my @parts = split /::/, $AUTOLOAD;
    local $_ = $parts[-1];
    
    return if $_ eq "DESTROY";

    my $val;

    if (/(set|unset)_(.*)/) {
        $val = $1 eq 'set';
        $_ = $2;
    }

    exists $self->{$_} or croak "No directive called $_";

    if (defined $val) {
        $self->{$_} = $val;
    }
    
    return $self->{$_};
}

