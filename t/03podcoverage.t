use strict;
use warnings;
use File::Spec::Functions qw( catdir updir );
use FindBin               qw( $Bin );
use lib               catdir( $Bin, updir, 'lib' );

use Test::More;

BEGIN {
   plan skip_all => 'POD coverage test only for developers'
      unless $ENV{AUTHOR_TESTING};
}

use English qw( -no_match_vars );

eval "use Test::Pod::Coverage 1.04";

plan skip_all => 'Test::Pod::Coverage 1.04 required' if $EVAL_ERROR;

all_pod_coverage_ok({ also_private => [qw( BUILD BUILDARGS as_string clone)] });

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
