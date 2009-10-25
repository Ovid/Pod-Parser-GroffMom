#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most tests => 4;
use Pod::Parser::Groffmom;

ok my $parser = Pod::Parser::Groffmom->new,
  'We should be able to create a new parser';
my $file = 't/test_pod.pod';
open my $fh, '<', $file or die "Cannot open ($file) for reading: $!";

can_ok $parser, 'parse_from_filehandle';
warning_like { $parser->parse_from_filehandle($fh) }
    qr/^Found \Q(=item * Second item)\E outside of list at line \d+/,
    '... and it should parse the file with a warning a bad =item';
is $parser->mom, get_mom(),
    '... and it should render the correct mom';

sub get_mom {
    my $mom = <<'END_MOM';
.TITLE "Some Doc"
.SUBTITLE "Some subtitle"
.AUTHOR "Curtis \[dq]Ovid\[dq] Poe"
.COPYRIGHT "2009, Some company"
.COVER TITLE SUBTITLE AUTHOR COPYRIGHT
.PRINTSTYLE TYPESET
\#
.FAM H
.PT_SIZE 12
.START
.HEAD "This is an attempt to generate a groff_mom file"

.SUBHEAD "This is another subheader"

We want POD text to \f[I]automatically\f[P] be converted to the correct format.

.L_MARGIN 1.25i
.LIST BULLET
.ITEM
First item
.ITEM
Second item
.LIST END

.L_MARGIN 1i
.NEWPAGE
.SUBHEAD "Verbatim sample"

.FAM C
.PT_SIZE 10
.LEFT
.L_MARGIN 1.25i
 If at first you don't succeed ...
 :wq
.QUAD
.L_MARGIN 1i
.FAM H
.PT_SIZE 12

.SUBHEAD "This is a \[dq]subheader"

This is a paragraph

END_MOM
}
