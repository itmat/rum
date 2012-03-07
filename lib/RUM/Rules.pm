package RUM::Rules;

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    return bless {
        rules => []
    }, $class;
}

sub add {
    my ($self, $targets, $prereqs, $commands, $comments) = @_;
    push @{ $self->{rules} }, {
        targets => $targets,
        prereqs => $prereqs,
        commands => $commands,
        comments => $comments
    };
}

sub makefile {
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

1;
