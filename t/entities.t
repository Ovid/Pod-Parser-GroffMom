#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most tests => 1;
use Pod::Parser::Groffmom;

my $parser = Pod::Parser::Groffmom->new;

open my $fh, '<', \<<'END' or die $!;
=head1 NAME

E<ntilde> eq E<241>

=head2 Some stuff

END

$parser->parse_from_filehandle($fh);
like $parser->mom, qr/.TITLE "\\N'241' eq \\N'241'"/,
    'E<> sequences should be parsed correctly';
