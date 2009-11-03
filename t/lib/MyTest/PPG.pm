package MyTest::PPG;

use strict;
use warnings;

use base 'Exporter';
our @EXPORT = qw(
  head
  body
);
our %EXPORT_TAGS = ( all => \@EXPORT );

sub head {
    my ( $data, $lines ) = @_;
    $lines ||= 1;
    $lines--;
    my @lines = split "\n" => $data;
    return @lines[ 0 .. $lines ];
}

sub body {
    my $data = shift;
    $data =~ s/^.*\n.START//s;
    return $data;
}

1;
