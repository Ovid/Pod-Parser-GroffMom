use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name       => 'Pod::Parser::Groffmom',
    license           => 'perl',
    dist_author       => 'Curtis "Ovid" Poe <ovid@cpan.org>',
    dist_version_from => 'lib/Pod/Parser/Groffmom.pm',
    requires          => {
        'Moose'           => 0.60,    # hope this one is good enough!
        'Perl6::Junction' => 1.4,
    },
    build_requires     => { 'Test::More' => 0, },
    add_to_cleanup     => ['Pod-Parser-Groffmom-*'],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
