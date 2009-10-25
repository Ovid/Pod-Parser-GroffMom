#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most 'no_plan';
use Pod::Parser::Groffmom;

ok my $parser = Pod::Parser::Groffmom->new,
  'We should be able to create a new parser';
my $file = 't/test_pod.pod';
open my $fh, '<', $file or die "Cannot open ($file) for reading: $!";
$parser->parse_from_filehandle($fh);
diag $parser->mom;
open my $out, '>', 'out.mom' or die "$!";
print $out $parser->mom;

sub get_mom {
    my $mom = <<'END_MOM';
.TITLE    "Some Doc"
.SUBTITLE "Some Subtitle"
.AUTHOR   "Curtis 'Ovid' Poe"
.COPYRIGHT "2009, Curtis 'Ovid' Poe"
.COVER TITLE SUBTITLE AUTHOR COPYRIGHT
.PRINTSTYLE TYPESET
\#
.FAM H
.PT 12
.START

.HEAD "This is a header"
.SUBHEAD "This is a subheader"

This is a paragraph

.L_MARGIN 1.25i
.LIST BULLET
.ITEM
First item
.ITEM
Second item
.LIST END
.L_MARGIN 1i

.L_MARGIN 1.25i
.LIST DIGIT
.ITEM
First item
.ITEM
Second item
.LIST END
.L_MARGIN 1i

.NEWPAGE

Let's have another
paragraph.

.FAM C
.LEFT
.L_MARGIN 1.25i
#!/usr/bin/env perl
use strict;
use warnings;
print "Hello, World\\n";
.QUAD
.L_MARGIN 1i
.FAM H
.PT 12

This is more text
that does not break
END_MOM
}
