package RUM::BlatAlignment;

use strict;
use warnings;

use base 'RUM::Alignment';

sub new {
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    for my $key (qw(mismatch q_gap_count q_name q_size q_start q_end t_name)) {
        $self->{$key} = $params{$key};
    }

    return $self;
}

sub mismatch    { shift->{mismatch} }
sub q_gap_count { shift->{q_gap_count} }
sub q_name      { shift->{q_name} }
sub q_size      { shift->{q_size} }
sub q_start     { shift->{q_start} }
sub q_end       { shift->{q_end} }
sub t_name      { shift->{t_name} }

1;
