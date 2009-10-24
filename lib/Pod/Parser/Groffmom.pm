package Pod::Parser::Groffmom;

use warnings;
use strict;
use Carp 'croak';

use Moose;
extends 'Pod::Parser';

my @MOM_METHODS = qw(title subtitle author copyright cover);

foreach my $method (@MOM_METHODS) {
    has $method       => ( is => 'rw', isa => 'Bool' );
    has "mom_$method" => ( is => 'rw', isa => 'Str' );
}
has head     => ( is => 'rw' );
has subhead  => ( is => 'rw' );
has mom_text => ( is => 'rw', isa => 'Str', default => '' );

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
    $self->$_(0) foreach @MOM_METHODS;
    $paragraph = $self->_trim($paragraph);

    # =head1 TITLE (upper case)
    my $is_mom = $paragraph eq uc $paragraph;
    $paragraph = lc $paragraph if $is_mom;
    print "Command $command ($paragraph)\n";
    if ($is_mom) {
        $paragraph = 'title' if $paragraph eq 'name';
        foreach my $method (@MOM_METHODS) {
            my $mom_method = "mom_$method";
            if ( $paragraph eq $method ) {
                if ( my $item = $self->$mom_method ) {
                    croak("Tried to reset $method ($item) at line $line_num");
                }
                $self->$method(1);
                $self->mom_cover(1) if $paragraph eq 'cover';
                return;
            }
        }
    }
    else {
        $paragraph = $self->_escape($paragraph);
        if ( 'head1' eq $command ) {
            $self->add_to_mom(qq{.HEAD "$paragraph"\n});
        }
        if ( 'head2' eq $command ) {
            $self->add_to_mom(qq{.SUBHEAD "$paragraph"\n});
        }
    }
}

sub add_to_mom {
    my ( $self, $text ) = @_;
    return unless defined $text;
    $self->mom_text( ($self->mom_text||'') . $text );
}

sub end_input {
    my $self = shift;
    my $mom  = '';

    foreach my $method (@MOM_METHODS) {
        next if 'cover' eq $method;
        my $mom_method = "mom_$method";
        my $macro      = ".\U$method";
        if ( my $item = $self->$mom_method ) {

            # handle double quotes later
            $mom .= qq{$macro "$item"\n};
        }
    }
    if ( $self->mom_cover ) {
        my $cover = ".COVER";
        foreach my $method (@MOM_METHODS) {
            my $mom_method = "mom_$method";
            next if 'cover' eq $method;
            next unless $self->$mom_method;
            $cover .= " \U$method";
        }
        $mom .= "$cover\n";
    }
    $mom .= <<'END';
.PRINTSTYLE TYPESET
\#
.FAM H
.PT 12
.START
END
    $mom .= $self->mom_text;
    open my $fh, '>', 'out.mom' or die "$!";
    print $fh $mom;
    print $mom;
}

sub _head1 { }
sub _head2 { }

sub verbatim {
    my ( $self, $verbatim, $paragraph, $line_num ) = @_;
    $paragraph = $self->_trim($paragraph);
    print "Verbatim ($verbatim) ($paragraph)\n";
    $self->add_to_mom(sprintf <<'END' => $verbatim);
.FAM C
.LEFT
.L_MARGIN 1.25i
%s
.QUAD
.L_MARGIN 1i
.FAM H
.PT 12
END
}

sub textblock {
    my ( $self, $textblock, $paragraph, $line_num ) = @_;
    $textblock = $self->_escape( $self->_trim($textblock) );
    print "Textblock $textblock ($paragraph)\n";
    foreach my $method (@MOM_METHODS) {
        my $mom_method = "mom_$method";
        if ( $self->$method ) {

            # This was set in command()
            $self->$mom_method($textblock);
            return;
        }
    }
    $self->add_to_mom($textblock);
}

sub interior_sequence {
    my ( $self, $sequence, $paragraph, $line_num ) = @_;
    $paragraph = $self->_trim($paragraph);
    print "Sequence $sequence ($paragraph)\n";
}

# verbatim()
# textblock()
# interior_sequence()

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
