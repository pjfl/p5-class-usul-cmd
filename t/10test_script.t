#!/usr/bin/env -S perl -I.
use t::boilerplate;

use File::Spec::Functions qw( devnull );
use Test::More;

use_ok 'Class::Usul::Cmd';

{  package TestCmd;

   our $VERSION = 0.1;

   use Moo;
   use Class::Usul::Cmd::Options;

   extends 'Class::Usul::Cmd';

   option 'test_attr' => is => 'ro';

   sub test_method : method {
   }

   sub random_method {
   }

   $INC{'TestCmd.pm'} = __FILE__;
}
{  package Test::Config;

   use Moo;

   has 'appclass' => is => 'ro', default => 'TestCmd';
}

my $obj = TestCmd->new_with_options(config => Test::Config->new());

is $obj->app_version, '0.1', 'App version';
ok !$obj->can_call, 'Can call requires an argument';
ok $obj->can_call('dump_config'), 'Can call dump_config_attr';
ok !$obj->can_call('can_call'), 'Cannot call can_call';
ok $obj->can_call('test_method'), 'Can call test method in Test class';
ok !$obj->can_call('random_method'), 'Cannot call random_method';
ok $obj->can('random_method'), 'Object can random_method';
ok $obj->can('test_attr'), 'Option is synonym for has';

$obj->unshift_argv('test-method');
is $obj->select_method, 'test_method', 'Dash 2 underscore on method';

$ENV{PERL_MM_USE_DEFAULT} = 1;

# To avoid open for writing error from logger
open STDIN, '<', devnull() or die 'Cannot open devnull';

ok !$obj->is_interactive, 'Is not interactive';
is $obj->anykey, 1, 'Any key';
is $obj->get_line( undef, 'test' ), 'test', 'Get line';
is $obj->get_option( undef, 2 ), 1, 'Get option';
is $obj->yorn( undef, 1 ), 1, 'Yes or no';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
