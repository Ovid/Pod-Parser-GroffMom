#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most 'no_plan';    #tests => 4;
use Pod::Parser::Groffmom;

my $parser = Pod::Parser::Groffmom->new;

open my $fh, '<', \<<'END' or die $!;
=head1 NAME

E<ntilde> eq E<241>
END
$parser->parse_from_filehandle($fh);
is head($parser->mom), qq{.TITLE "\\N'241' eq \\N'241'"},
    'E<> sequences should be parsed correctly';

sub head {
    my ( $text, $num ) = @_;
    $num ||= 1;
    $num--;
    my @lines = split "\n" => $text;
    return @lines[ 0 .. $num ];
}

