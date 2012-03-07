package RUM::Rules;

=head1 NAME

RUM::Rules - Work in progress. Will handle modeling task dependencies in RUM.

=head1 SYNOPSYS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

sub _new {
    my ($class, %options) = @_;
    return bless {
        rules => []
    }, $class;
}

sub _add {
    my ($self, $targets, $prereqs, $commands, $comments) = @_;
    push @{ $self->{rules} }, {
        targets => $targets,
        prereqs => $prereqs,
        commands => $commands,
        comments => $comments
    };
}

sub _makefile {
    my ($self) = @_;
    my $result  = "";
    my @clean;
    for my $rule (@{ $self->{rules} }) {
        my @targets = @{ $rule->{targets} };
        my @prereqs = @{ $rule->{prereqs} };
        my @commands = @{ $rule->{commands} };
        my $comments = $rule->{comments};

        push @clean, @targets;

        $result .= "# $comments\n" if $comments;
        $result .= "@targets : @prereqs\n";
        for my $command (@commands) {
            $result .= "\t$command\n";
        }
        $result .= "\n";
    }
    
    $result .= "clean :\n\trm -f @clean\n";

    return $result;
}

=head1 AUTHOR

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

=cut

1;
