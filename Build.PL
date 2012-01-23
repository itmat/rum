use 5.006;
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'RUM::Index',
    license             => 'perl',
    dist_author         => q{Mike DeLaurentis <delaurentis@gmail.com>},
    dist_version_from   => 'lib/RUM/Index.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'perl' => 5.006,
    },
    add_to_cleanup      => [ 'RUM-Index-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
