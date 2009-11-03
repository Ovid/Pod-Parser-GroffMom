package Pod::Parser::Groffmom;

use warnings;
use strict;
use Carp qw(carp croak);
use Perl6::Junction 'any';
use Pod::Parser::Groffmom::Color ':all';
use Pod::Parser::Groffmom::Entities 'entity_to_num';

use Moose;
use MooseX::NonMoose;
use Moose::Util::TypeConstraints 'enum';
extends qw(Pod::Parser);

# order of MOM_METHODS is very important.  See '.COPYRIGHT' in mom docs.
my @MOM_METHODS  = qw(title subtitle author copyright);
my @MOM_BOOLEANS = qw(cover newpage toc);
my %IS_MOM       = map { uc($_) => 1 } ( @MOM_METHODS, @MOM_BOOLEANS );

foreach my $method ( __PACKAGE__->mom_methods, __PACKAGE__->mom_booleans ) {
    has $method                       => ( is => 'rw', isa => 'Bool' );
    has "mom_$method"                 => ( is => 'rw', isa => 'Str' );
    has "$method\_set_in_constructor" => ( is => 'rw', isa => 'Bool' );
}

sub BUILD {
    my $self = shift;
    foreach my $method ( __PACKAGE__->mom_methods, __PACKAGE__->mom_booleans )
    {
        my $mom = "mom_$method";
        my $ctr = "$method\_set_in_constructor";
        if ( $self->$mom ) {
            $self->$ctr(1);
        }
    }
}

has head    => ( is => 'rw' );
has subhead => ( is => 'rw' );
has mom     => ( is => 'rw', isa => 'Str', default => '' );
has toc => ( is => 'rw', => isa => 'Bool' );
has highlight => ( is => 'rw' );

# list helpers
has in_list_mode => ( is => 'rw', isa => 'Int', default => 0 );
has list_data    => ( is => 'rw', isa => 'Str', default => '' );
has list_type => ( is => 'rw', isa => enum( [ '', qw/BULLET DIGIT/ ] ) );

sub mom_methods  { @MOM_METHODS }
sub mom_booleans { @MOM_BOOLEANS }

sub is_mom {
    my ( $class, $command, $paragraph ) = @_;
    $DB::single = 1;
    if ( $command =~ /^head[123]/ ) {
        return 1 if $paragraph eq 'NAME';    # special alias for 'TITLE'
        return $IS_MOM{$paragraph};
    }
    elsif ( $command eq 'for' ) {
        return 1 if $paragraph =~ /^mom\s+\w+/;
    }
}

=head1 NAME

Pod::Parser::Groffmom - Convert POD to a format groff_mom can handle.

=head1 VERSION

Version 0.030

=cut

our $VERSION = '0.030';
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

    # We need to do this list dots appear at the beginning of a line an look
    # like mom macros.  This can happen if you have a some inline sequences
    # terminating a sentence (e.g. "See the module S<C<Foo::Module>>.").
    $text =~ s/\./\\N'46'/g;

    return $text;
}

sub command {
    my ( $self, $command, $paragraph, $line_num ) = @_;

    # reset mom_methods
    $self->$_(0) foreach $self->mom_methods;
    $paragraph = $self->_trim($paragraph);

    my $is_mom = $self->is_mom($command, $paragraph);
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
        my $ctr        = "$method\_set_in_constructor";
        if ( $paragraph eq $method ) {
            if ( my $item = $self->$mom_method ) {
                croak("Tried to reset $method ($item) at line $line_num")
                    unless $self->$ctr;
            }
            $self->$method(1);
            return;
        }
    }
    $self->mom_cover(1)             if $paragraph =~ /^mom\s+cover/i;
    $self->mom_toc(1)               if $paragraph =~ /^mom\s+toc/i;
    $self->add_to_mom(".NEWPAGE\n") if $paragraph =~ /^mom\s+newpage/i;
}

{
    my %command_handler = (
        head1 => sub {
            my ( $self, $paragraph ) = @_;
            $paragraph = $self->interpolate($paragraph);
            $self->add_to_mom(qq{.HEAD "$paragraph"\n\n});
        },
        head2 => sub {
            my ( $self, $paragraph ) = @_;
            $paragraph = $self->interpolate($paragraph);
            $self->add_to_mom(qq{.SUBHEAD "$paragraph"\n\n});
        },
        head3 => sub {
            my ( $self, $paragraph ) = @_;
            $paragraph = $self->interpolate($paragraph);
            $self->add_to_mom(qq{\\f[B]$paragraph\\f[P]\n\n});
        },
        begin => sub {
            my ( $self, $paragraph ) = @_;
            $paragraph = $self->_trim($paragraph);
            my ( $target, $language ) =
              $paragraph =~ /^(highlight)(?:\s+(.*))?$/;
            if ( $target && !$language ) {
                $language = 'Perl';
            }
            $self->highlight( get_highlighter($language) );
        },
        end => sub {
            my ( $self, $paragraph ) = @_;
            $paragraph = $self->_trim($paragraph);
            if ( $paragraph eq 'highlight' ) {
                $self->highlight('');
            }
        },
        pod => sub { },    # noop
    );

    sub handler_for {
        my ( $self, $command ) = @_;
        return $command_handler{$command};
    }
}

sub build_mom {
    my ( $self, $command, $paragraph, $line_num ) = @_;
    $paragraph = $self->_escape($paragraph);
    if ( any(qw/over item back/) eq $command ) {
        $self->build_list( $command, $paragraph, $line_num );
    }
    elsif ( my $handler = $self->handler_for($command) ) {
        $self->$handler($paragraph);
    }
    else {
        carp("Unknown command ($command) at line $line_num");
    }
}

sub build_list {
    my ( $self, $command, $paragraph, $line_num ) = @_;
    if ( 'over' eq $command ) {
        $self->in_list_mode( $self->in_list_mode + 1 );
        $self->list_type('');
    }
    elsif ( 'back' eq $command ) {
        if ( $self->in_list_mode == 0 ) {
            warn "=back without =over at line $line_num";
            return;
        }
        else {
            $self->in_list_mode( $self->in_list_mode - 1 );
            $self->list_data( $self->list_data . ".LIST END\n" );
        }
        if ( !$self->in_list_mode ) {
            my $list =
                ".L_MARGIN 1.25i\n"
              . $self->list_data
              . "\n.L_MARGIN 1i\n";
            $self->add_to_mom($list);
            $self->list_data('');
        }
    }
    elsif ( 'item' eq $command ) {
        if ( not $self->in_list_mode ) {
            carp(
"Found (=item $paragraph) outside of list at line $line_num.  Discarding"
            );
            return;
        }
        $paragraph =~ /^(\*|\d+)?\s*(.*)/;
        my ( $list_type, $item ) = ( $1, $2 );
        $list_type ||= '';
        $list_type = '*' ne $list_type ? 'DIGIT' : 'BULLET';

        # default to BULLET if we cannot identify the list type
        if ( not $self->list_type ) {
            $self->list_type($list_type);
            $self->list_data( $self->list_data . ".LIST $list_type\n" );
        }
        $item = $self->interpolate($item);
        $self->add_to_list(".ITEM\n$item\n");
    }
}

sub add_to_mom {
    my ( $self, $text ) = @_;
    return unless defined $text;
    $self->mom( ( $self->mom ) . $text );
}

sub add_to_list {
    my ( $self, $text ) = @_;
    return unless defined $text;
    $text = $self->interpolate($text);
    $self->list_data( ( $self->list_data ) . $text );
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
    $self->mom( $mom .= $self->mom );
    $self->mom( $self->mom . ".TOC\n" ) if $self->mom_toc;
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
    $textblock = $self->interpolate( $textblock, $line_num );
    foreach my $method ( $self->mom_methods ) {
        my $mom_method = "mom_$method";
        my $ctr        = "$method\_set_in_constructor";

        if ( $self->$method ) {

            # Don't override these values if set in the contructor
            if ( not $self->$ctr ) {
                # This was set in command()
                $self->$mom_method($textblock);
            }
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

{
    my %handler_for = (
        I => sub {    # italics
            my ( $self, $paragraph ) = @_;
            return "\\f[I]$paragraph\\f[P]";
        },
        C => sub {    # code
            my ( $self, $paragraph ) = @_;
            return "\\f[C]$paragraph\\f[P]";
        },
        B => sub {    # bold
            my ( $self, $paragraph ) = @_;
            return "\\f[B]$paragraph\\f[P]";
        },
        E => sub {    # entity
            my ( $self, $paragraph ) = @_;
            my $num = entity_to_num($paragraph);
            return "\\N'$num'";
        },
        L => sub {    # link
            my ( $self, $paragraph ) = @_;

            # This is legal because the POD docs are quite specific about this.
            my $strip_quotes = sub { $_[0] =~ s/^"|"$//g };

            if ( $paragraph !~ m{(?:/|\|)} ) { # no / or |
                # L<Net::Ping>
                return "\\f[C]$paragraph\\f[P]";
            }
            elsif ( $paragraph =~ m{^([^/]*)\|(.+)$} ) {
                # L<the Net::Ping module|Net::Ping>
                # L<support section|PPI/SUPPORT>
                my ($text, $name) = ( $1, $2 );

                $strip_quotes->($_) foreach $text, $name;
                if ($name eq $text) {
                    return "\\f[C]$text\\f[P]";
                }
                else {
                    return qq{$text (\\f[C]$name\\f[P])};
                }
            }
            elsif ( $paragraph =~ m{^(.*)/(.*)} ) {
                my ( $name, $text ) = ( $1, $2 );
                $strip_quotes->($_) foreach $text, $name;
                return "$text (\\f[C]$name\\f[P])";
            }
            else {
                # XXX eventually we'll need better handling of this
                warn "Unknown sequence format for L<$paragraph>";
                return qq{"$paragraph"};
            }
        },
        F => sub {    # filename
            my ( $self, $paragraph ) = @_;
            return "\\f[I]$paragraph\\f[P]";
        },
        S => sub {    # non-breaking spaces
            my ( $self, $paragraph ) = @_;
            $paragraph =~ s/\s/\\~/g; # non-breaking space
            return " \\c\n.HYPHENATE OFF\n$paragraph\\c\n.HYPHENATE\n";
        },
        Z => sub {    # null-effect sequence
            my ( $self, $paragraph ) = @_;
            return '';
        },
        X => sub {    # indexes
            my ( $self, $paragraph ) = @_;
            return $paragraph;
            # XXX Rats.  Didn't work.
            # return "$paragraph\\c\n.IQ $paragraph\\c\n";    # XXX would love to do something here
        },
    );

    sub sequence_handler {
        my ( $self, $sequence ) = @_;
        return $handler_for{$sequence};
    }
}

sub interior_sequence {
    my ( $self, $sequence, $paragraph ) = @_;
    if ( my $handler = $self->sequence_handler($sequence) ) {
        return $self->$handler($paragraph);
    }
    else {
        carp(
"Unknown sequence ($sequence<$paragraph>).  Stripping sequence code."
        );
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

If you prefer, read C<perldoc pod2mom> for an easier interface.

=head1 DESCRIPTION

This subclass of C<Pod::Parser> will take a POD file and produce "mom"
output.  See L<http://linuxgazette.net/107/schaffter.html> for a gentle
introduction.

If you have C<groff> on your system, it I<should> have docs for "momdoc".
Otherwise, you can read them at 
L<http://www.opensource.apple.com/source/groff/groff-28/groff/contrib/mom/momdoc/toc.html?f=text>.

The "mom" documentation is not needed to use this module, but it would be
needed if you wish to hack on it.

=head1 CONSTRUCTOR

The following arguments may be supplied to the constructor and override any
values found in the POD document.

=over 4

=item * C<mom_title>

=item * C<mom_subtitle>

=item * C<mom_author>

=item * C<mom_copyright>

=item * C<mom_cover> (creates a cover page)

=item * C<mom_toc> (creates a table of contents)

=back

=head1 ALPHA CODE

This is alpha code.  There's not much control over it yet and there are plenty
of POD corner cases it doesn't handle.

=head1 MOM COMMANDS

Most POD files will convert directly to "mom" output.  However, when you view
the result, you might want more control over it.  The following is how
MOM directives are handled.  They may begin with either '=head1' or =head2'.
It doesn't matter (this might change later).

Some commands which should alter mom behavior but not show up in the POD begin
with C<=for>.

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

 =for mom COVER

Does not require any text after it.  This is merely a boolean command telling
C<Pod::Parser::Groffmom> to create a cover page.

=item * newpage

 =for mom newpage

Does not require any text after it.  This is merely a boolean command telling
C<Pod::Parser::Groffmom> to create page break here.

=item * TOC

 =for mom TOC

Does not require any text after it.  This is merely a boolean command telling
C<Pod::Parser::Groffmom> to create a table of contents.  Due to limitations in
with C<groff -mom>, the table of contents will be the final page of the
document.

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

For a list of allowable names for syntax highlighting, see
C<Pod::Parser::Groffmom::Color>.

=back

=head1 SPECIAL CHARACTERS

Special characters are often encountered in POD:

 Salvador FandiE<ntilde>o

To see the list of named characters we support, check
L<Pod::Parser::Groffmom::Entities>.  If the character you need is not on that
list, you may still enter its numeric value.  The above name could also be
written as:

 Salvador FandiE<241>o

=head1 LIMITATIONS

Probably plenty.

=over 4

=item * We don't yet handle numbered lists well (they always start with '1')

=item * List indent level (C<=over 4>) ignored.

=item * Syntax highlighting is experimental.

=item * No support for hyperlinks.  C<< L<> >> is rendered with quotes.

=item * No C<=head4> or below are supported.

=item * Table of contents are generated at the end. This is a limitation of mom.

=item * C<=for...> not handled.

=item * C<SE<lt>E<gt>> sequences try to work but they're finicky.

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

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;    # End of Pod::Parser::Groffmom
