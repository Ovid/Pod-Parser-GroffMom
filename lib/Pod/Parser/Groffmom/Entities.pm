package Pod::Parser::Groffmom::Entities;

use strict;
use warnings;

=head1 NAME

Pod::Parser::Groffmom::Entities - Internal entity conversions

=head1 VERSION

Version 0.030

=cut

our $VERSION = '0.030';
$VERSION = eval $VERSION;


use parent 'Exporter';
our @EXPORT_OK = 'entity_to_num';
my %entity2char = (
    amp  => 38,    # ampersand
    gt   => 62,    # greater than
    lt   => 60,    # less than
    quot => 34,    # double quote
    apos => 39,    # single quote

    # PUBLIC ISO 8879-1986//ENTITIES Added Latin 1//EN//HTML
    AElig  => 198,    # capital AE diphthong (ligature)
    Aacute => 193,    # capital A, acute accent
    Acirc  => 194,    # capital A, circumflex accent
    Agrave => 192,    # capital A, grave accent
    Aring  => 197,    # capital A, ring
    Atilde => 195,    # capital A, tilde
    Auml   => 196,    # capital A, dieresis or umlaut mark
    Ccedil => 199,    # capital C, cedilla
    ETH    => 208,    # capital Eth, Icelandic
    Eacute => 201,    # capital E, acute accent
    Ecirc  => 202,    # capital E, circumflex accent
    Egrave => 200,    # capital E, grave accent
    Euml   => 203,    # capital E, dieresis or umlaut mark
    Iacute => 205,    # capital I, acute accent
    Icirc  => 206,    # capital I, circumflex accent
    Igrave => 204,    # capital I, grave accent
    Iuml   => 207,    # capital I, dieresis or umlaut mark
    Ntilde => 209,    # capital N, tilde
    Oacute => 211,    # capital O, acute accent
    Ocirc  => 212,    # capital O, circumflex accent
    Ograve => 210,    # capital O, grave accent
    Oslash => 216,    # capital O, slash
    Otilde => 213,    # capital O, tilde
    Ouml   => 214,    # capital O, dieresis or umlaut mark
    THORN  => 222,    # capital THORN, Icelandic
    Uacute => 218,    # capital U, acute accent
    Ucirc  => 219,    # capital U, circumflex accent
    Ugrave => 217,    # capital U, grave accent
    Uuml   => 220,    # capital U, dieresis or umlaut mark
    Yacute => 221,    # capital Y, acute accent
    aacute => 225,    # small a, acute accent
    acirc  => 226,    # small a, circumflex accent
    aelig  => 230,    # small ae diphthong (ligature)
    agrave => 224,    # small a, grave accent
    aring  => 229,    # small a, ring
    atilde => 227,    # small a, tilde
    auml   => 228,    # small a, dieresis or umlaut mark
    ccedil => 231,    # small c, cedilla
    eacute => 233,    # small e, acute accent
    ecirc  => 234,    # small e, circumflex accent
    egrave => 232,    # small e, grave accent
    eth    => 240,    # small eth, Icelandic
    euml   => 235,    # small e, dieresis or umlaut mark
    iacute => 237,    # small i, acute accent
    icirc  => 238,    # small i, circumflex accent
    igrave => 236,    # small i, grave accent
    iuml   => 239,    # small i, dieresis or umlaut mark
    ntilde => 241,    # small n, tilde
    oacute => 243,    # small o, acute accent
    ocirc  => 244,    # small o, circumflex accent
    ograve => 242,    # small o, grave accent
    oslash => 248,    # small o, slash
    otilde => 245,    # small o, tilde
    ouml   => 246,    # small o, dieresis or umlaut mark
    szlig  => 223,    # small sharp s, German (sz ligature)
    thorn  => 254,    # small thorn, Icelandic
    uacute => 250,    # small u, acute accent
    ucirc  => 251,    # small u, circumflex accent
    ugrave => 249,    # small u, grave accent
    uuml   => 252,    # small u, dieresis or umlaut mark
    yacute => 253,    # small y, acute accent
    yuml   => 255,    # small y, dieresis or umlaut mark

    # Some extra Latin 1 chars that are listed in the HTML3.2 draft (21-May-96)
    copy => 169,      # copyright sign
    reg  => 174,      # registered sign
    nbsp => 160,      # non breaking space

    # Additional ISO-8859/1 entities listed in rfc1866 (section 14)
    iexcl    => 161,
    cent     => 162,
    pound    => 163,
    curren   => 164,
    yen      => 165,
    brvbar   => 166,
    sect     => 167,
    uml      => 168,
    ordf     => 170,
    laquo    => 171,
    not      => 172,    # not is a keyword in perl
    shy      => 173,
    macr     => 175,
    deg      => 176,
    plusmn   => 177,
    sup1     => 185,
    sup2     => 178,
    sup3     => 179,
    acute    => 180,
    micro    => 181,
    para     => 182,
    middot   => 183,
    cedil    => 184,
    ordm     => 186,
    raquo    => 187,
    frac14   => 188,
    frac12   => 189,
    frac34   => 190,
    iquest   => 191,
    times    => 215,    # times is a keyword in perl
    divide   => 247,
    OElig    => 338,
    oelig    => 339,
    Scaron   => 352,
    scaron   => 353,
    Yuml     => 376,
    fnof     => 402,
    circ     => 710,
    tilde    => 732,
    Alpha    => 913,
    Beta     => 914,
    Gamma    => 915,
    Delta    => 916,
    Epsilon  => 917,
    Zeta     => 918,
    Eta      => 919,
    Theta    => 920,
    Iota     => 921,
    Kappa    => 922,
    Lambda   => 923,
    Mu       => 924,
    Nu       => 925,
    Xi       => 926,
    Omicron  => 927,
    Pi       => 928,
    Rho      => 929,
    Sigma    => 931,
    Tau      => 932,
    Upsilon  => 933,
    Phi      => 934,
    Chi      => 935,
    Psi      => 936,
    Omega    => 937,
    alpha    => 945,
    beta     => 946,
    gamma    => 947,
    delta    => 948,
    epsilon  => 949,
    zeta     => 950,
    eta      => 951,
    theta    => 952,
    iota     => 953,
    kappa    => 954,
    lambda   => 955,
    mu       => 956,
    nu       => 957,
    xi       => 958,
    omicron  => 959,
    pi       => 960,
    rho      => 961,
    sigmaf   => 962,
    sigma    => 963,
    tau      => 964,
    upsilon  => 965,
    phi      => 966,
    chi      => 967,
    psi      => 968,
    omega    => 969,
    thetasym => 977,
    upsih    => 978,
    piv      => 982,
    ensp     => 8194,
    emsp     => 8195,
    thinsp   => 8201,
    zwnj     => 8204,
    zwj      => 8205,
    lrm      => 8206,
    rlm      => 8207,
    ndash    => 8211,
    mdash    => 8212,
    lsquo    => 8216,
    rsquo    => 8217,
    sbquo    => 8218,
    ldquo    => 8220,
    rdquo    => 8221,
    bdquo    => 8222,
    dagger   => 8224,
    Dagger   => 8225,
    bull     => 8226,
    hellip   => 8230,
    permil   => 8240,
    prime    => 8242,
    Prime    => 8243,
    lsaquo   => 8249,
    rsaquo   => 8250,
    oline    => 8254,
    frasl    => 8260,
    euro     => 8364,
    image    => 8465,
    weierp   => 8472,
    real     => 8476,
    trade    => 8482,
    alefsym  => 8501,
    larr     => 8592,
    uarr     => 8593,
    rarr     => 8594,
    darr     => 8595,
    harr     => 8596,
    crarr    => 8629,
    lArr     => 8656,
    uArr     => 8657,
    rArr     => 8658,
    dArr     => 8659,
    hArr     => 8660,
    forall   => 8704,
    part     => 8706,
    exist    => 8707,
    empty    => 8709,
    nabla    => 8711,
    isin     => 8712,
    notin    => 8713,
    ni       => 8715,
    prod     => 8719,
    sum      => 8721,
    minus    => 8722,
    lowast   => 8727,
    radic    => 8730,
    prop     => 8733,
    infin    => 8734,
    ang      => 8736,
    and      => 8743,
    or       => 8744,
    cap      => 8745,
    cup      => 8746,
    int      => 8747,
    there4   => 8756,
    sim      => 8764,
    cong     => 8773,
    asymp    => 8776,
    ne       => 8800,
    equiv    => 8801,
    le       => 8804,
    ge       => 8805,
    sub      => 8834,
    sup      => 8835,
    nsub     => 8836,
    sube     => 8838,
    supe     => 8839,
    oplus    => 8853,
    otimes   => 8855,
    perp     => 8869,
    sdot     => 8901,
    lceil    => 8968,
    rceil    => 8969,
    lfloor   => 8970,
    rfloor   => 8971,
    lang     => 9001,
    rang     => 9002,
    loz      => 9674,
    spades   => 9824,
    clubs    => 9827,
    hearts   => 9829,
    diams    => 9830,
);


sub entity_to_num {
    my $entity = shift;
    return $entity if $entity =~ /^\d+$/;
    return $entity2char{$entity} || '';
}

1;
