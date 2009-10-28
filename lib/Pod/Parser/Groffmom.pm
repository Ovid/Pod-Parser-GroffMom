package Pod::Parser::Groffmom;

use warnings;
use strict;
use Carp qw(carp croak);
use Perl6::Junction 'any';
use Pod::Parser::Groffmom::Color ':all';

use Moose;
use Moose::Util::TypeConstraints 'enum';
extends qw(Pod::Parser Moose::Object);

# order of MOM_METHODS is very important.  See '.COPYRIGHT' in mom docs.
my @MOM_METHODS  = qw(title subtitle author copyright);
my @MOM_BOOLEANS = qw(cover newpage);
my %IS_MOM       = map { uc($_) => 1 } ( @MOM_METHODS, @MOM_BOOLEANS );

foreach my $method ( @MOM_METHODS, @MOM_BOOLEANS ) {
    has $method       => ( is => 'rw', isa => 'Bool' );
    has "mom_$method" => ( is => 'rw', isa => 'Str' );
}
has head    => ( is => 'rw' );
has subhead => ( is => 'rw' );
has mom     => ( is => 'rw', isa => 'Str', default => '' );
has highlight => ( is => 'rw' );

# list helpers
has list_data => ( is => 'rw', isa => 'Str', default => '' );
has in_list_mode => ( is => 'rw', isa => 'Bool' );
has list_type => ( is => 'rw', isa => enum( [qw/BULLET DIGIT/] ) );

sub mom_methods  { @MOM_METHODS }
sub mom_booleans { @MOM_BOOLEANS }

sub is_mom {
    my ( $class, $command ) = @_;
    return 1 if $command eq 'NAME'; # special alias for 'TITLE'
    return $IS_MOM{$command};
}

=head1 NAME

Pod::Parser::Groffmom - Convert POD to a format groff_mom can handle.

=head1 VERSION

Version 0.020

=cut

our $VERSION = '0.020';
$VERSION = eval $VERSION;

sub _trim {
    local $_ = $_[1];
    s/^\s+|\s+$//gs;
    return $_;
}

sub _escape {
    my ( $self, $text ) = @_;
    $text =~ s/"/\\[dq]/g;

    # This is a quick and nasty hack, but we assume that we escape all
    # backslashes unless they look like they're followed by a mom escape
    $text =~ s/\\(?!\[\w+\])/\\\\/g;
    return $text;
}

sub command {
    my ( $self, $command, $paragraph, $line_num ) = @_;

    # reset mom_methods
    $self->$_(0) foreach $self->mom_methods;
    $paragraph = $self->_trim($paragraph);

    my $is_mom = $self->is_mom($paragraph);
    $paragraph = lc $paragraph if $is_mom;
    if ($is_mom) {
        $self->parse_mom( $command, $paragraph, $line_num );
    }
    else {
        $self->build_mom( $command, $paragraph, $line_num );
    }
}

sub parse_mom {
    my ( $self, $command, $paragraph, $line_num ) = @_;
    $paragraph = 'title' if $paragraph eq 'name';
    foreach my $method ( $self->mom_methods ) {
        my $mom_method = "mom_$method";
        if ( $paragraph eq $method ) {
            if ( my $item = $self->$mom_method ) {
                croak("Tried to reset $method ($item) at line $line_num");
            }
            $self->$method(1);
            return;
        }
    }
    $self->mom_cover(1)             if $paragraph eq 'cover';
    $self->add_to_mom(".NEWPAGE\n") if $paragraph eq 'newpage';
}

sub build_mom {
    my ( $self, $command, $paragraph, $line_num ) = @_;
    $paragraph = $self->_escape($paragraph);
    if ( 'head1' eq $command ) {
        $self->add_to_mom(qq{.HEAD "$paragraph"\n\n});
    }
    elsif ( 'head2' eq $command ) {
        $self->add_to_mom(qq{.SUBHEAD "$paragraph"\n\n});
    }
    elsif ( 'head3' eq $command ) {
        $self->interpolate($paragraph);
        $self->add_to_mom(qq{\\f[B]$paragraph\\f[P]\n\n});
    }
    elsif ( any(qw/over item back/) eq $command ) {
        $self->build_list( $command, $paragraph, $line_num );
    }
    elsif ( 'begin' eq $command ) {
        $paragraph = $self->_trim($paragraph);
        my ( $target, $language ) = $paragraph =~ /^(highlight)(?:\s+(\S*))?$/;
        if ( $target && !$language ) {
            $language = 'Perl';
        }
        $self->highlight(get_highlighter($language));
    }
    elsif ( 'end' eq $command ) {
        $paragraph = $self->_trim($paragraph);
        if ( $paragraph eq 'highlight' ) {
            $self->highlight('');
        }
    }
    else {
        carp("Unknown command ($command) at line $line_num");
    }
}

sub build_list {
    my ( $self, $command, $paragraph, $line_num ) = @_;
    if ( 'over' eq $command ) {
        $self->in_list_mode(1);
    }
    elsif ( 'back' eq $command ) {
        my $list =
            ".L_MARGIN 1.25i\n.LIST "
          . $self->list_type . "\n"
          . $self->list_data
          . ".LIST END\n\n.L_MARGIN 1i\n";
        $self->add_to_mom($list);
        $self->list_data('');
        $self->in_list_mode(0);
    }
    elsif ( 'item' eq $command ) {
        if ( not $self->in_list_mode ) {
            carp("Found (=item $paragraph) outside of list at line $line_num.  Discarding");
            return;
        }
        $paragraph =~ /^(\*|\d+)?\s*(.*)/;
        my ( $list_type, $item ) = ( $1, $2 );

        # default to BULLET if we cannot identify the list type
        $self->list_type( $list_type ne '*' ? 'DIGIT' : 'BULLET' )
          if not $self->list_type;
        $item = $self->interpolate($item);
        $self->add_to_list(".ITEM\n$item\n");
    }
}

sub add_to_mom {
    my ( $self, $text ) = @_;
    return unless defined $text;
    $self->mom( ( $self->mom || '' ) . $text );
}

sub add_to_list {
    my ( $self, $text ) = @_;
    return unless defined $text;
    $text = $self->interpolate($text);
    $self->list_data( ( $self->list_data || '' ) . $text );
}

sub end_input {
    my $self = shift;
    my $mom  = '';

    foreach my $method ( $self->mom_methods ) {
        my $mom_method = "mom_$method";
        my $macro      = ".\U$method";
        if ( my $item = $self->$mom_method ) {

            # handle double quotes later
            $mom .= qq{$macro "$item"\n};
        }
    }
    if ( $self->mom_cover ) {
        my $cover = ".COVER";
        foreach my $method ( $self->mom_methods ) {
            my $mom_method = "mom_$method";
            next unless $self->$mom_method;
            $cover .= " \U$method";
        }
        $mom .= "$cover\n";
    }
    my $color_definitions = Pod::Parser::Groffmom::Color->color_definitions;
    $mom .= <<"END";
.PRINTSTYLE TYPESET
\\#
.FAM H
.PT_SIZE 12
\\#
$color_definitions
.START
END
    $self->mom($mom .= $self->mom);
}

sub verbatim {
    my ( $self, $verbatim, $paragraph, $line_num ) = @_;
    $verbatim =~ s/\s+$//s;
    if ( $self->highlight ) {
        $verbatim = $self->highlight->highlightText($verbatim);
    }
    else {
        $verbatim = $self->_escape($verbatim);
    }
    $self->add( sprintf <<'END' => $verbatim );
.FAM C
.PT_SIZE 10
.LEFT
.L_MARGIN 1.25i
%s
.QUAD
.L_MARGIN 1i
.FAM H
.PT_SIZE 12

END
}

sub textblock {
    my ( $self, $textblock, $paragraph, $line_num ) = @_;
    $textblock = $self->_escape( $self->_trim($textblock) );
    $textblock = $self->interpolate($textblock, $line_num);
    foreach my $method ( $self->mom_methods ) {
        my $mom_method = "mom_$method";
        if ( $self->$method ) {

            # This was set in command()
            $self->$mom_method($textblock);
            return;
        }
    }
    $self->add("$textblock\n\n");
}

sub add {
    my ( $self, $data ) = @_;
    my $add = $self->in_list_mode ? 'add_to_list' : 'add_to_mom';
    $self->$add($data);
}

sub interior_sequence {
    my ( $self, $sequence, $paragraph ) = @_;

    $paragraph = $self->_trim($paragraph);
    if ( $sequence eq 'I' ) {
        return "\\f[I]$paragraph\\f[P]";
    }
    elsif ( $sequence eq 'C' ) {
        return "\\f[C]$paragraph\\f[P]";
    }
    elsif ( $sequence eq 'B' ) {
        return "\\f[B]$paragraph\\f[P]";
    }
    elsif ( $sequence eq 'E' ) {
        return "\\N'$paragraph'";
    }
    else {
        carp("Unknown sequence ($sequence<$paragraph>).  Stripping sequence code.");
        return $paragraph;
    }
}

=head1 SYNOPSIS

    use Pod::Parser::Groffmom;
    my $foo  = Pod::Parser::Groffmom->new();
    my $file = 't/test_pod.pod';
    open my $fh, '<', $file 
      or die "Cannot open ($file) for reading: $!";
    $parser->parse_from_filehandle($fh);
    print $parser->mom;

If you have printed the "mom" output to file named 'my.mom', you can then do this:

  groff -mom my.mom > my.ps

And you will have a postscript file suitable for opening in C<gv>, Apple's
C<Preview.app> or anything else which can read postscript files.

=head1 DESCRIPTION

This subclass of C<Pod::Parser> will take a POD file and produce "mom"
output.  See L<http://linuxgazette.net/107/schaffter.html> for a gentle
introduction.

If you have C<groff> on your system, it I<should> have docs for "momdoc".
Otherwise, you can read them at 
L<http://www.opensource.apple.com/source/groff/groff-28/groff/contrib/mom/momdoc/toc.html?f=text>.

The "mom" documentation is not needed to use this module, but it would be
needed if you wish to hack on it.

=head1 ALPHA CODE

This is alpha code.  There's not much control over it yet and there are plenty
of POD corner cases it doesn't handle.

=head1 MOM COMMANDS

Most POD files will convert directly to "mom" output.  However, when you view
the result, you might want more control over it.  The following is how
MOM directives are handled.  They may begin with either '=head1' or =head2'.
It doesn't matter (this might change later).

=over 4

=item * NAME

 =head1 NAME

 This is the title of the pod.

Whatever follows "NAME" will be the title of your document.

=item * TITLE

 =head1 TITLE

 This is the title of the pod.

Synonymous with 'NAME'.  You may only have one title for a document.

=item * SUBTITLE

 =head1 SUBTITLE

 This is the subtitle of the pod.

=item * AUTHOR

 =head1 AUTHOR

 Curtis "Ovid" Poe

This is the author of your document.

=item * COPYRIGHT

 =head1 COPYRIGHT

 2009, Curtis "Ovid" Poe

This will be the copyright statement on your pod.  Will only appear in the
document if the C<=head1 COVER> command is given.

=item * COVER

 =head1 COVER

Does not require any text after it.  This is merely a boolean command telling
C<Pod::Parser::Groffmom> to create a cover page.

=item * NEWPAGE

 =head1 NEWPAGE

Does not require any text after it.  This is merely a boolean command telling
C<Pod::Parser::Groffmom> to create page break here.

=item * begin highlight

 =begin highlight Perl
   
  sub add {
      my ( $self, $data ) = @_;
      my $add = $self->in_list_mode ? 'add_to_list' : 'add_to_mom';
      $self->$add($data);
  }

 =end highlight

This turns on syntax highlighting.  Allowable highlight types are the types
allowed for C<Syntax::Highlight::Engine::Kate>.  We default to Perl, so the
above can be written as:

 =begin highlight 
   
  sub add {
      my ( $self, $data ) = @_;
      my $add = $self->in_list_mode ? 'add_to_list' : 'add_to_mom';
      $self->$add($data);
  }

 =end highlight

=back

=head1 LIMITATIONS

Probably plenty.

=over 4

=item * We don't yet handle numbered lists.

=item * Lines of POD starting with a dot '.' character may behave unexpectedly.

=item * Inline sequences are handled poorly.

=item * Syntax highlighting is experimental and a bit flaky.

Some lines after comments are highlighted as comments.  Also, POD in verbatim
(indented) POD highlights incorrectly.  C<Common_Lisp> is allegedly supported
by C<Syntax::Highlight::Engine::Kate>, but we were getting weird stack errors
when we tried to highlight it.

Also, don't use angle brackets with quote operators like C<q> or C<qq>.  The
highlighter gets confused.

=back

=head1 AUTHOR

Curtis "Ovid" Poe, C<< <ovid at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-pod-parser-groffmom at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Pod-Parser-Groffmom>.  I will
be notified, and then you'll automatically be notified of progress on your bug
as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Pod::Parser::Groffmom

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Pod-Parser-Groffmom>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Pod-Parser-Groffmom>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Pod-Parser-Groffmom>

=item * Search CPAN

L<http://search.cpan.org/dist/Pod-Parser-Groffmom/>

=back

=head1 REPOSITORY

The latest version of this module can be found at
L<http://github.com/Ovid/Pod-Parser-GroffMom>.

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2009 Curtis "Ovid" Poe, all rights reserved.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;    # End of Pod::Parser::Groffmom
