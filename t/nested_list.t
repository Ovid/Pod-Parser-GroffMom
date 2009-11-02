#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most tests => 1;
use Pod::Parser::Groffmom;

my $parser = Pod::Parser::Groffmom->new;

open my $fh, '<', \<<'END' or die $!;
=head1 NAME

Nested Lists

=head1 List

=over 4

=item * One

=item * Two

=over 4

=item * Un

=item * Deux

=item * Trois

=back

=item * Three

=back

END

$parser->parse_from_filehandle($fh);
my $expected_mom = do { local $/; <DATA> };
eq_or_diff $parser->mom, $expected_mom, 'Nested lists should parse correctly';

__END__
.TITLE "Nested Lists"
.PRINTSTYLE TYPESET
\#
.FAM H
.PT_SIZE 12
\#
.NEWCOLOR Alert        RGB #0000ff
.NEWCOLOR BaseN        RGB #007f00
.NEWCOLOR BString      RGB #c9a7ff
.NEWCOLOR Char         RGB #ff00ff
.NEWCOLOR Comment      RGB #7f7f7f
.NEWCOLOR DataType     RGB #0000ff
.NEWCOLOR DecVal       RGB #00007f
.NEWCOLOR Error        RGB #ff0000
.NEWCOLOR Float        RGB #00007f
.NEWCOLOR Function     RGB #007f00
.NEWCOLOR IString      RGB #ff0000
.NEWCOLOR Operator     RGB #ffa500
.NEWCOLOR Others       RGB #b03060
.NEWCOLOR RegionMarker RGB #96b9ff
.NEWCOLOR Reserved     RGB #9b30ff
.NEWCOLOR String       RGB #ff0000
.NEWCOLOR Variable     RGB #0000ff
.NEWCOLOR Warning      RGB #0000ff

.START
.HEAD "List"

.L_MARGIN 1.25i
.LIST BULLET
.ITEM
One
.ITEM
Two
.LIST BULLET
.ITEM
Un
.ITEM
Deux
.ITEM
Trois
.LIST END
.ITEM
Three
.LIST END

.L_MARGIN 1i
