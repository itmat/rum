package RUM::BlatAlignment;

use strict;
use warnings;

use base 'RUM::Alignment';

sub new {
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    for my $key (qw(mismatch q_gap_count t_gap_count q_name q_size q_start q_end t_name
                    q_gap_bases
                    block_count block_sizes q_starts t_starts)) {
        $self->{$key} = $params{$key};
    }

    return $self;
}

sub mismatch    { shift->{mismatch} }
sub q_gap_count { shift->{q_gap_count} }
sub q_gap_bases { shift->{q_gap_bases} }
sub t_gap_count { shift->{t_gap_count} }
sub q_name      { shift->{q_name} }
sub q_size      { shift->{q_size} }
sub q_start     { shift->{q_start} }
sub q_end       { shift->{q_end} }
sub t_name      { shift->{t_name} }

sub block_count { shift->{block_count} }
sub block_sizes { [ split /,/, shift->{block_sizes} ] }
sub q_starts    { [ split /,/, shift->{q_starts}    ] }
sub t_starts    { [ split /,/, shift->{t_starts}    ] }

sub block_sizes_str { join '', (map { "$_," } @{ shift->block_sizes } )};
sub q_starts_str { join '', (map { "$_," } @{ shift->q_starts } )};
sub t_starts_str { join '', (map { "$_," } @{ shift->t_starts } )};
1;
