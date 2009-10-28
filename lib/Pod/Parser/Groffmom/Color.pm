package Pod::Parser::Groffmom::Color;

=head1 NAME

Pod::Parser::Groffmom - Color formatting for groff -mom.

=head1 VERSION

Version 0.020

=cut

our $VERSION = '0.020';

$VERSION = eval $VERSION;

use warnings;
use strict;

use base 'Exporter';
our @EXPORT = qw(color_definitions get_highlighter);
our %EXPORT_TAGS = ( all => \@EXPORT );

use Syntax::Highlight::Engine::Kate;

sub color_definitions {
    return <<'    END';
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
    END
}

sub get_highlighter {
    my ($language) = @_;
    return Syntax::Highlight::Engine::Kate->new(
        language      => $language,
        substitutions => { "\\" => "\\\\", },
        format_table  => {
            Alert        => [ "\\*[Alert]",              "\\*[black]" ],
            BaseN        => [ "\\*[BaseN]",              "\\*[black]" ],
            BString      => [ "\\*[BString]",            "\\*[black]" ],
            Char         => [ "\\*[Char]",               "\\*[black]" ],
            Comment      => [ "\\*[Comment]\\f[I]",      "\\f[P]\\*[black]" ],
            DataType     => [ "\\*[DataType]",           "\\*[black]" ],
            DecVal       => [ "\\*[DecVal]",             "\\*[black]" ],
            Error        => [ "\\*[Error]\\f[BI]",       "\\f[P]\\*[black]" ],
            Float        => [ "\\*[Float]",              "\\*[black]" ],
            Function     => [ "\\*[Function]",           "\\*[black]" ],
            IString      => [ "\\*[IString]",            "" ],
            Keyword      => [ "\\f[B]",                  "\\f[P]" ],
            Normal       => [ "",                        "" ],
            Operator     => [ "\\*[Operator]",           "\\*[black]" ],
            Others       => [ "\\*[Others]",             "\\*[black]" ],
            RegionMarker => [ "\\*[RegionMarker]\\f[I]", "\\[P]\\*[black]" ],
            Reserved     => [ "\\*[Reserved]\\f[B]",     "\\f[P]\\*[black]" ],
            String       => [ "\\*[String]",             "\\*[black]" ],
            Variable     => [ "\\*[Variable]\\f[B]",     "\\f[P]\\*[black]" ],
            Warning      => [ "\\*[Warning]\\f[BI]",     "\\f[P]\\*[black]" ],
        },
    );
}

1;
