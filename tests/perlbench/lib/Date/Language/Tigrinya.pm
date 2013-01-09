##
## Tigrinya tables
##

package Date::Language::Tigrinya;

use Date::Language ();
use vars qw(@ISA @DoW @DoWs @MoY @MoYs @AMPM @Dsuf %MoY %DoW $VERSION);
@ISA = qw(Date::Language);
$VERSION = "1.00";

@DoW = qw(
"\x{U1230}\x{U1295}\x{U1260}\x{U1275}",
"\x{U1230}\x{U1291}\x{U12ed}",
"\x{U1230}\x{U1209}\x{U1235}",
"\x{U1228}\x{U1261}\x{U12d5}",
"\x{U1213}\x{U1219}\x{U1235}",
"\x{U12d3}\x{U122d}\x{U1262}",
"\x{U1240}\x{U12f3}\x{U121d}"
);
@MoY = qw(
"\x{U1303}\x{U1295}\x{U12e9}\x{U12c8}\x{U122a}",
"\x{U134c}\x{U1265}\x{U1229}\x{U12c8}\x{U122a}",
"\x{U121b}\x{U122d}\x{U127d}",
"\x{U12a4}\x{U1355}\x{U1228}\x{U120d}",
"\x{U121c}\x{U12ed}",
"\x{U1301}\x{U1295}",
"\x{U1301}\x{U120b}\x{U12ed}",
"\x{U12a6}\x{U1308}\x{U1235}\x{U1275}",
"\x{U1234}\x{U1355}\x{U1274}\x{U121d}\x{U1260}\x{U122d}",
"\x{U12a6}\x{U12ad}\x{U1270}\x{U12cd}\x{U1260}\x{U122d}",
"\x{U1296}\x{U126c}\x{U121d}\x{U1260}\x{U122d}",
"\x{U12f2}\x{U1234}\x{U121d}\x{U1260}\x{U122d}"
);
@DoWs = map { substr($_,0,3) } @DoW;
@MoYs = map { substr($_,0,3) } @MoY;
@AMPM = (
"\x{1295}/\x{1230}",
"\x{12F5}/\x{1230}"
);

@Dsuf = ("\x{12ed}" x 31);

@MoY{@MoY}  = (0 .. scalar(@MoY));
@MoY{@MoYs} = (0 .. scalar(@MoYs));
@DoW{@DoW}  = (0 .. scalar(@DoW));
@DoW{@DoWs} = (0 .. scalar(@DoWs));

# Formatting routines

sub format_a { $DoWs[$_[0]->[6]] }
sub format_A { $DoW[$_[0]->[6]] }
sub format_b { $MoYs[$_[0]->[4]] }
sub format_B { $MoY[$_[0]->[4]] }
sub format_h { $MoYs[$_[0]->[4]] }
sub format_p { $_[0]->[2] >= 12 ?  $AMPM[1] : $AMPM[0] }

1;
