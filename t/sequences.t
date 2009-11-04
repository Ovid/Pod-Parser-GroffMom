#!/usr/bin/env perl

use strict;
use warnings;

use lib 't/lib';
use MyTest::PPG ':all';
use Test::Most 'no_plan'; #tests => 1;
use Pod::Parser::Groffmom;

my $parser = Pod::Parser::Groffmom->new;

open my $fh, '<', \<<'END' or die $!;
=head1 Nested sequences

C<< <I<alias>=I<rulename>> >>

END

my $expected_body = <<'END';

.HEAD "Nested sequences"

\f[C]<\f[P]\f[CI]alias\f[P]\f[C]=\f[P]\f[CI]rulename\f[P]\f[C]>\f[P]

END

# was: \f[C]<\f[I]alias\f[P]=\f[I]rulename\f[P]>\f[P]
$parser->parse_from_filehandle($fh);
eq_or_diff body($parser->mom), $expected_body,
    'Nested seqeunces should group codes correctly';
