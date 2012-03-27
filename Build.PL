use 5.006;
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->subclass(
    code => q(
      sub ACTION_testintegration { shift->generic_test(type => 'integration'); }
    )
)->new(
    module_name         => 'RUM::Pipeline',
    license             => 'perl',
    dist_author         => q{Mike DeLaurentis <delaurentis@gmail.com>},
    dist_version_from   => 'lib/RUM/Pipeline.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'perl' => 5.006,
    },
    add_to_cleanup      => [ 'RUM-Pipeline-*' ],
    create_makefile_pl => 'traditional',
    configure_requires => { 'Module::Build' => 0.38 },
    test_types => {
        integration => 'it'
    }
);

$builder->create_build_script();
