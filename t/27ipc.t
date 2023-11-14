use t::boilerplate;

use Test::More;
use File::Spec::Functions qw( catdir catfile tmpdir );
use English qw( -no_match_vars );
use File::Basename;

{  package Logger;

   sub new   { return bless {}, __PACKAGE__ }
   sub alert { warn '[ALERT] ' . $_[1] . "\n" }
   sub debug { }
   sub error { warn '[ERROR] ' . $_[1] . "\n" }
   sub fatal { warn '[ALERT] ' . $_[1]  ."\n" }
   sub info  { warn '[ALERT] ' . $_[1] . "\n" }
   sub warn  { warn '[WARNING] ' . $_[1] . "\n" }
}

use Class::Usul::Cmd::Constants qw(EXCEPTION_CLASS);
use File::DataClass::IO qw( io );
use Class::Usul::Cmd;

my $osname = lc $OSNAME;
my $perl   = $EXECUTABLE_NAME;
{  package TestCmd;

   our $VERSION = 0.1;

   use Moo;
   use Class::Usul::Cmd::Options;

   extends 'Class::Usul::Cmd';

   $INC{'TestCmd.pm'} = __FILE__;
}
{  package Test::Config;

   use Moo;

   has 'appclass' => is => 'ro', default => 'TestCmd';
}

my $obj = TestCmd->new_with_options(
   config => Test::Config->new(),
   log    => Logger->new,
   method => 'dump_self',
   quiet  => 1,
);

sub run_cmd_test {
   my $want = shift;
   my $r = eval { $obj->run_cmd(@_) };

   $EVAL_ERROR    and return $EVAL_ERROR;
   $want eq 'err' and return $r->stderr;
   $want eq 'out' and return $r->out;
   $want eq 'rv'  and return $r->rv;
   return $r;
}

my ($cmd, $r);

SKIP: {
   $osname eq 'mswin32' and skip 'system test - not on MSWin32', 5;

   $cmd = "${perl} -v"; $r = run_cmd_test( 'out', $cmd, { use_system => 1 } );

   like $r, qr{ larry \s+ wall }imsx, 'system - captures stdout';

   $cmd = "${perl} -e \"exit 2\"";
   $r   = run_cmd_test( q(), $cmd, { use_system => 1 } );

   is ref $r, EXCEPTION_CLASS, 'system - exception is right class';

   like $r, qr{ Unknown \s+ error }msx, 'system - default error string';

   is run_cmd_test( 'rv', $cmd, { expected_rv => 2, use_system => 1 } ), 2,
      'system - expected rv';

   $r = run_cmd_test( q(), $cmd, { async => 1 } );

   like $r->out, qr{ background }msx, 'system - async';

   $cmd = "${perl} -e \"sleep 5\"";

   is run_cmd_test( q(), $cmd, { timeout => 1, use_system => 1 } )->class,
      'TimeOut', 'system - timeout';
   wait;

   $cmd = "${perl} -e \"print <>\"";

   my $args = { in => 'test', use_system => 1 };

   is run_cmd_test( 'out', $cmd, $args ), 'test', 'system - captures stdin';
}

SKIP: {
   ($osname eq 'mswin32' or $osname eq 'cygwin')
      and skip 'IPC::Run test - not on MSWin32 or Cygwin', 6;

   eval { require IPC::Run }; $EVAL_ERROR
      and skip 'IPC::Run test - not installed', 6;

   $cmd = [ $perl, '-v' ];

   like run_cmd_test( 'out', $cmd, { use_ipc_run => 1 } ),
      qr{ larry \s+ wall }imsx, 'IPC::Run - captures stdout';

   $cmd = [ $perl, '-e', 'exit 1' ];

   like run_cmd_test( q(), $cmd, { use_ipc_run => 1 } ),
      qr{ Unknown \s+ error }msx, 'IPC::Run - default error string';

   is run_cmd_test( 'rv', $cmd, { expected_rv => 1, use_ipc_run => 1 } ), 1,
      'IPC::Run - expected rv';

   $cmd = [ $perl, '-v' ];
   $r   = run_cmd_test( q(), $cmd, { async => 1, use_ipc_run => 1 } );

   like $r->out, qr{ background }msx, 'IPC::Run - async';

   $cmd = [ sub { print 'Hello World' } ];
   $r   = run_cmd_test( q(), $cmd, { async => 1, use_ipc_run => 1 } );

   $ENV{AUTHOR_TESTING}
      and like $r->out, qr{ background }msx, 'IPC::Run - async coderef';
   unlike $r->rv,  qr{ \(-1\) }msx,     'IPC::Run - async coderef captures pid';

   $cmd = [ $perl, '-e', 'sleep 5' ];

   is run_cmd_test( q(), $cmd, { timeout => 1, use_ipc_run => 1 } )->class,
      'TimeOut', 'IPC::Run - timeout';
   wait;

   $cmd = [ $perl, '-e', 'print <>' ];

   my $args = { in => 'test', partition_cmd => 0, use_ipc_run => 1 };

   is run_cmd_test( 'out', $cmd, $args ), 'test', 'IPC::Run - captures stdin';
}

SKIP: {
   $osname eq 'mswin32' and skip 'fork and exec - not on MSWin32', 1;
   $cmd = [ $perl, '-v' ];

   like run_cmd_test( 'out', $cmd ), qr{ larry \s+ wall }imsx,
      'fork and exec - captures stdout';

   my $path = io [ qw( t outfile ) ];

   run_cmd_test( q(), $cmd, { out => $path } );

   like $path->slurp, qr{ larry \s+ wall }imsx,
      'fork and exec - captures stdout to file';

   $path->exists and $path->unlink;
   $cmd = [ $perl, '-e', 'warn "danger"' ];

   like run_cmd_test( 'err', $cmd ), qr{ danger }mx,
      'fork and exec - captures stderr';

   like run_cmd_test( 'out', $cmd, { err => 'out' } ), qr{ danger }mx,
      'fork and exec - dups stderr on stdout';

   $cmd = [ $perl, '-e', 'exit 1' ];

   like run_cmd_test( q(), $cmd ),
      qr{ Unknown \s+ error }msx, 'fork and exec - default error string';

   is run_cmd_test( 'rv', $cmd, { expected_rv => 1 } ), 1,
      'fork and exec - expected rv';

   $cmd = [ $perl, '-v' ];

   like run_cmd_test( 'out', $cmd, { async => 1 } ),
      qr{ background }msx, 'fork and exec - async';

   $cmd = [ sub { print 'Hello World' } ];
   $r   = run_cmd_test( q(), $cmd, { async => 1, out => $path } );

   like    $r->out, qr{ background }msx, 'fork and exec - async coderef';
   unlike  $r->rv,  qr{ \(-1\) }msx,
      'fork and exec - async coderef captures pid';
   waitpid $r->pid, 0;
   is $path->slurp, 'Hello World', 'fork and exec - async coderef writes file';

   $path->exists and $path->unlink;
   $cmd = [ $perl, '-e', 'sleep 5' ];

   is run_cmd_test( q(), $cmd, { timeout => 1 } )->class,
      'TimeOut', 'fork and exec - timeout';

   if (-x '/bin/sleep') {
      $cmd = [ '/bin/sleep', '2' ];
      $r   = run_cmd_test( q(), $cmd, { expected_rv => 255 } );
      is $r->rv, 0, 'fork and exec - external command expected rv';
   }

   $r = run_cmd_test( q(), [ $perl, '-v' ], { detach => 1, out => $path } );

   like $r->out, qr{ background }imsx, 'fork and exec - detaches';
   waitpid $r->pid, 0;

   if ($osname ne 'solaris') {
      like $path->slurp, qr{ larry \s+ wall }imsx,
         'fork and exec - detaches and writes file';
   }
   else {
      my $stat = $path->stat;

      diag sprintf 'File %s size %d mode %o',
         $path, $stat->{size}, $stat->{mode} & 0777;
   }

   $path->exists and $path->unlink;

   is run_cmd_test( 'out', [ $perl, '-e', 'print <>' ], { in => 'test' } ),
      'test', 'fork and exec - captures stdin';

   $r = run_cmd_test( q(), [ '/bin/not_found' ], { expected_rv => 255 } );

   $ENV{AUTHOR_TESTING} and like "${r}", qr{ \Qfailed to exec\E }imx,
      'fork and exec - traps exec failure';
}

# This fails on some platforms. The stderr is not redirected as expected
#eval { $obj->run_cmd( "unknown_command_xa23sd3", { debug => 1 } ) };

#ok $EVAL_ERROR =~ m{ unknown_command }mx, 'unknown command';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
