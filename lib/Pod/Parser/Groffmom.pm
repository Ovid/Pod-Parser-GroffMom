package Pod::Parser::Groffmom;

use warnings;
use strict;
use Carp qw(carp croak);
use Perl6::Junction 'any';

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

Version 0.01

=cut

our $VERSION = '0.001';
$VERSION = eval $VERSION;

sub _trim {
    local $_ = $_[1];
    s/^\s+|\s+$//gs;
    return $_;
}

sub _escape {
    my ( $self, $text ) = @_;
    $text =~ s/"/\\[dq]/g;
    return $text;
}

sub command {
    my ( $self, $command, $paragraph, $line_num ) = @_;

    # reset mom_methods
    $self->$_(0) foreach $self->mom_methods;
    $paragraph = $self->_trim($paragraph);

    my $is_mom = $self->is_mom($paragraph);
    $paragraph = lc $paragraph if $is_mom;
    print "Command $command ($paragraph)\n";
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
        $self->add_to_mom(qq{\\f[B]$paragraph\\f[P]\n\n});
    }
    elsif ( any(qw/over item back/) eq $command ) {
        $self->build_list( $command, $paragraph, $line_num );
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
    $mom .= <<'END';
.PRINTSTYLE TYPESET
\#
.FAM H
.PT_SIZE 12
.START
END
    $self->mom($mom .= $self->mom);
}

sub verbatim {
    my ( $self, $verbatim, $paragraph, $line_num ) = @_;
    $paragraph = $self->_trim($paragraph);
    print "Verbatim ($verbatim) ($paragraph)\n";
    $verbatim =~ s/\s+$//s;
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
    print "Textblock $textblock ($paragraph)\n";
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
    my ( $self, $sequence, $paragraph, $line_num ) = @_;
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
    else {
        carp("Uknown sequence ($sequence<$paragraph> at line $line_num)");
        return "$sequence<$paragraph>";
    }
}

=head1 SYNOPSIS

    use Pod::Parser::Groffmom;
    my $foo = Pod::Parser::Groffmom->new();

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

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2009 Curtis "Ovid" Poe, all rights reserved.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;    # End of Pod::Parser::Groffmom
