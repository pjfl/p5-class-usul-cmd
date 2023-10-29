package Class::Usul::Cmd::IPC::Runtime;

use Class::Usul::Cmd::Constants qw( EXCEPTION_CLASS FALSE NUL OK SPC TRUE
                                    UNDEFINED_RV );
use Class::Usul::Cmd::Util      qw( arg_list emit_to is_member is_win32
                                    nap nonblocking_write_pipe_pair
                                    strip_leader tempdir throw );
use Class::Usul::Cmd::Types     qw( ArrayRef Bool LoadableClass Logger
                                    NonEmptySimpleStr Num Object PositiveInt
                                    SimpleStr Str Undef );
use English                     qw( -no_match_vars );
use File::Basename              qw( basename );
use File::DataClass::IO         qw( io );
use File::DataClass::Types      qw( Directory Path );
use File::Spec::Functions       qw( devnull rootdir );
use Module::Load::Conditional   qw( can_load );
use POSIX                       qw( _exit setsid sysconf WIFEXITED WNOHANG );
use Ref::Util                   qw( is_arrayref is_coderef is_hashref );
use Scalar::Util                qw( blessed openhandle weaken );
use Socket                      qw( AF_UNIX SOCK_STREAM PF_UNSPEC );
use Sub::Install                qw( install_sub );
use Unexpected::Functions       qw( TimeOut Unspecified );
use IO::Handle;
use IO::Select;
use IPC::Open3;
use Try::Tiny;

use Moo; use warnings NONFATAL => 'all';

our ($CHILD_ENUM, $CHILD_PID);

=pod

=encoding utf-8

=head1 Name

Class::Usul::Cmd::IPC::Runtime - Execute system commands

=head1 Synopsis

   use Class::Usul::Cmd::IPC::Runtime;

   sub run_cmd {
      my ($self, $cmd, @args) = @_;

      my $attr = arg_list @args;

      $attr->{cmd    } = $cmd or throw Unspecified, ['command'];
      $attr->{log    } = $self->log;
      $attr->{rundir } = $self->config->rundir;
      $attr->{tempdir} = $self->config->tempdir;

      return Class::Usul::Cmd::IPC::Runtime->new($attr)->run_cmd;
   }

   $self->run_cmd(['perl', '-v'], { async => 1 });

   # Alternatively there is a functional interface

   use Class::Usul::IPC::Cmd { tempdir => ... }, 'run_cmd';

   run_cmd([ 'perl', '-v' ], { async => 1 });

=head1 Description

Refactored L<IPC::Cmd> with a consistent OO API

Would have used L<MooseX::Daemonize> but using L<Moo> not L<Moose> so
robbed some code from there instead

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<async>

Boolean defaults to false. If true the call to C<run_cmd> will return without
waiting for the child process to complete. If true the C<ignore_zombies>
attribute will default to true

=item C<close_all_files>

Boolean defaults to false. If true and the C<detach> attribute is also true
then all open file descriptors in the child are closed except those in the
C<keep_fhs> list attribute

=item C<cmd>

An array reference or a simple string. Required. The external command to
execute

=item C<detach>

Boolean defaults to false. If true the child process will double fork, set
the session id and ignore hangup signals

=item C<err>

A L<File::DataClass::IO> object reference or a simple string. Defaults to null.
Determines where the standard error of the command will be redirected to.
Values are the same as for C<out>. Additionally a value of 'out' will
redirect standard error to standard output

=item C<expected_rv>

Positive integer default to zero. The maximum return value which is
considered a success

=item C<ignore_zombies>

Boolean defaults to false unless the C<async> attribute is true in which case
this attribute also defaults to true. If true ignores child processes. If you
plan to call C<waitpid> to wait for the child process to finish you should
set this to false

=item C<in>

A L<File::DataClass::IO> object reference or a simple string. Defaults to null.
Determines where the standard input of the command will be redirected from.
Object references should stringify to the name of the file containing input.
A scalar is the input unless it is 'stdin' or 'null' which cause redirection
from standard input and the null device

=item C<keep_fhs>

An array reference of file handles that are to be left open in detached
children

=item C<log>

A log object defaults to an instance of L<Class::Null>. Calls are made to
it at the debug level

=item C<max_pidfile_wait>

Positive integer defaults to 15. The maximum number of seconds the parent
process should wait for the child's PID file to appear and be populated

=item C<nap_time>

Positive number defaults to 0.3. The number of seconds to wait between testing
for the existence of the child's PID file

=item C<out>

A L<File::DataClass::IO> object reference or a simple string. Defaults to null.
Determines where the standard output of the command will be redirected to.
Values include;

=over 3

=item C<null>

Redirect to the null device as defined by L<File::Spec>

=item C<stdout>

Output is not redirected to standard output

=item C<$object_ref>

The object reference should stringify to the name of a file to which standard
output will be redirected

=back

=item C<partition_cmd>

Boolean default to true. If the L<IPC::Run> implementation is selected the
command array reference will be partitioned on meta character boundaries
unless this attribute is set to false

=item C<pidfile>

A L<File::DataClass::IO> object reference. Defaults to a temporary file
in the configuration C<rundir> which will automatically unlink when closed

=item C<rundir>

A L<File::DataClass::IO> object reference. Defaults to the C<tempdir>
attribute. Directory in which the PID files a stored

=item C<tempdir>

A L<File::DataClasS::IO> object reference. Defaults to C<tmpdir> from
L<File::Spec>. The directory for storing temporary files

=item C<timeout>

Positive integer defaults to 0. If greater then zero an alarm will be raised
after this many seconds if the external command has not completed

=item C<use_ipc_run>

Boolean defaults to false. If true forces the use of the L<IPC::Rum>
implementation

=item C<use_system>

Boolean defaults to false. If true forces the use of the C<system>
implementation

=item C<working_dir>

A L<File::DataClass::IO> object reference. Defaults to null. If set the child
will C<chdir> to this directory before executing the external command

=back

=cut

has 'async' => is => 'ro',   isa => Bool, default => FALSE;

has 'close_all_files' => is => 'ro',   isa => Bool, default => FALSE;

has 'cmd' => is => 'ro', isa => ArrayRef | Str, required => TRUE;

has 'detach' => is => 'ro', isa => Bool, default => FALSE;

has 'err' => is => 'ro', isa => Path | SimpleStr, default => NUL;

has 'expected_rv' => is => 'ro', isa => PositiveInt, default => 0;

has 'ignore_zombies' =>
   is      => 'lazy',
   isa     => Bool,
   builder => sub {
      return ($_[ 0 ]->async || $_[ 0 ]->detach) ? TRUE : FALSE;
   };

has 'in' =>
   is      => 'ro',
   isa     => Path | SimpleStr,
   coerce  => sub {
      return (is_arrayref $_[0]) ? join $RS, @{$_[0]} : $_[0];
   },
   default => NUL;

has 'log' => is => 'ro', isa => Logger, required => TRUE;

has 'keep_fhs' =>
   is      => 'lazy',
   isa     => ArrayRef,
   builder => sub {
      return $_[0]->log->can('filehandle') ? [ $_[0]->log->filehandle ] : [];
   };

has 'max_pidfile_wait' => is => 'ro', isa => PositiveInt, default => 15;

has 'nap_time' => is => 'ro', isa => Num, default => 0.3;

has 'out' => is => 'ro', isa => Path | SimpleStr, default => NUL;

has 'partition_cmd' => is => 'ro', isa => Bool, default => TRUE;

has 'pidfile' =>
   is      => 'lazy',
   isa     => Path,
   coerce  => TRUE,
   builder => sub { $_[0]->rundir->tempfile };

has 'response_class' =>
   is      => 'lazy',
   isa     => LoadableClass,
   coerce  => TRUE,
   default => 'Class::Usul::Cmd::IPC::Response';

has 'rundir' =>
   is      => 'lazy',
   isa     => Directory,
   coerce  => TRUE,
   builder => sub { $_[0]->tempdir };

has 'tempdir' =>
   is      => 'lazy',
   isa     => Directory,
   builder => sub { tempdir },
   coerce  => TRUE,
   handles => { _tempfile => 'tempfile' };

has 'timeout' => is => 'ro', isa => PositiveInt, default => 0;

has 'use_ipc_run' => is => 'ro', isa => Bool, default => FALSE;

has 'use_system' => is => 'ro', isa => Bool, default => FALSE;

has 'working_dir' =>
   is      => 'lazy',
   isa     => Directory | Undef,
   coerce  => TRUE,
   default => sub { $_[0]->detach ? io rootdir : undef };

=head1 Subroutines/Methods

=over 3

=item C<BUILDARGS>

   $obj_ref = Class::Usul::IPC::Cmd->new( cmd => ..., out => ... );
   $obj_ref = Class::Usul::IPC::Cmd->new( { cmd => ..., out => ... } );
   $obj_ref = Class::Usul::IPC::Cmd->new( $cmd, out => ... );
   $obj_ref = Class::Usul::IPC::Cmd->new( $cmd, { out => ... } );
   $obj_ref = Class::Usul::IPC::Cmd->new( $cmd );

The constructor accepts a list of keys and values, a hash reference, the
command followed by a list of keys and values, the command followed by a
hash reference

=cut

around 'BUILDARGS' => sub { # Differentiate constructor method signatures
   my ($orig, $self, @args) = @_;

   my $n = 0; $n++ while (defined $args[$n]);

   return (            $n == 0) ? {}
        : (is_hashref $args[0]) ? { %{ $args[0] } }
        : (            $n == 1) ? { cmd => $args[0] }
        : (is_hashref $args[1]) ? { cmd => $args[0], %{$args[1]} }
        : (        $n % 2 == 1) ? { cmd => @args }
                                : { @args };
};

=item C<BUILD>

Set chomp and lock on the C<pidfile>

=cut

sub BUILD {
   my $self = shift;

   $self->pidfile->chomp->lock;
   return;
}

=item C<import>

Exports L<run_cmd> as a function into the calling package

=cut

sub import { # Export run_cmd as a function on demand
   my $class  = shift;
   my $params = { (is_hashref $_[0]) ? %{+ shift } : () };
   my @wanted = @_;
   my $target = caller;

   return unless is_member 'run_cmd', @wanted;

   install_sub { as => 'run_cmd', into => $target, code => sub {
      my $cmd  = shift;
      my $attr = arg_list @_;

      throw Unspecified, ['command'] unless $attr->{cmd} = $cmd;

      $attr->{$_} //= $params->{$_} for (keys %{$params});

      return __PACKAGE__->new($attr)->_run_cmd;
   }};

   return;
}

=item C<run_cmd>

   $response_object = Class::Usul::Cmd::IPC::Runtime->run_cmd( $cmd, @args );

Can be called as a class method or an object method

Runs a given external command. If the command argument is an array reference
the internal C<fork> and C<exec> implementation will be used, if a string is
passed the L<IPC::Open3> implementation will be use instead

Returns a L<Class::Usul::Cmd::IPC::Response> object reference

=cut

sub run_cmd { # Either class or object method
   my $self = (blessed $_[0]) ? $_[0] : __PACKAGE__->new(@_);

   return $self->_run_cmd;
}

# Private methods
sub _detach_process { # And this method came from MooseX::Daemonize
   my $self = shift;

   throw 'Cannot detach from controlling process' unless setsid;
   $SIG{HUP} = 'IGNORE';
   _exit OK if fork;
#  Clearing file creation mask allows direct control of the access mode of
#  created files and directories in open, mkdir, and mkpath functions
   umask 0;

   if ($self->close_all_files) { # Close all fds except the ones we should keep
      my $openmax = sysconf(&POSIX::_SC_OPEN_MAX);

      $openmax = 64 if not defined $openmax or $openmax < 0;

      for (grep { not is_member $_, $self->keep_fhs } 0 .. $openmax) {
         POSIX::close($_);
      }
   }

   $self->pidfile->println($PID);
   return;
}

sub _ipc_run_harness {
   my ($self, $cmd_ref, @cmd_args) = @_;

   if ($self->async) {
      $cmd_ref = $cmd_ref->[0] if is_coderef $cmd_ref->[0];

      my $pidfile = $self->pidfile; weaken($pidfile);
      my $h = IPC::Run::harness($cmd_ref, @cmd_args, init => sub {
         IPC::Run::close_terminal(); $pidfile->println($PID)
      }, '&');

      $h->start;
      return (0, $h);
   }

   my $h  = IPC::Run::harness($cmd_ref, @cmd_args);

   $h->run;

   my $rv = $h->full_result || 0;

   throw $rv if $rv =~ m{ unknown }msx;

   return ($rv, $h);
}

sub _new_async_response {
   my ($self, $pid) = @_;

   my $prog = basename($self->cmd->[0]);

   $self->log->debug(my $out = "Running ${prog}(${pid}) in the background");

   return $self->response_class->new(out => $out, pid => $pid);
}

sub _redirect_child_io {
   my ($self, $pipes) = @_;

   my $in  = $self->in || 'null';
   my $out = $self->out;
   my $err = $self->err;

   if ($self->async or $self->detach) { $out ||= 'null'; $err ||= 'null' }

   _redirect_stdin(($in eq 'null') ? devnull : $pipes->[0]->[0])
      unless $in eq 'stdin';

   _redirect_stdout((blessed $out) ? "${out}" : ($out eq 'null')
                    ? devnull : $pipes->[1]->[1]
   ) unless $out eq 'stdout';

   _redirect_stderr((blessed $err) ? "${err}" : ($err eq 'null')
                    ? devnull : $pipes->[2]->[1]
   ) unless $err eq 'stderr';

   # Avoid 'stdin reopened for output' warning with newer Perls
   open NULL, devnull; <NULL> if 0;

   return;
}

sub _return_codes_or_throw {
   my ($self, $cmd, $e_num, $e_str) = @_;

   $e_str ||= 'Unknown error'; chomp $e_str;

   if ($e_num == UNDEFINED_RV) {
      my $error = 'Program [_1] failed to start: [_2]';
      my $prog  = basename((split SPC, $cmd)[0]);

      throw $error, [$prog, $e_str], level => 3, rv => UNDEFINED_RV;
   }

   my $rv   = $e_num >> 8;
   my $core = $e_num & 128;
   my $sig  = $e_num & 127;

   if ($rv > $self->expected_rv) {
      $self->log->debug(my $error = "${e_str} rv ${rv}");
      throw $error, level => 3, rv => $rv;
   }

   return { core => $core, rv => $rv, sig => $sig, };
}

sub _shutdown {
   my $self = shift;
   my $pidfile = $self->pidfile;

   $self->pidfile->unlink if $pidfile->exists and $pidfile->getline == $PID;

   _exit OK;
}

sub _wait_for_pidfile_and_read {
   my $self    = shift;
   my $pidfile = $self->pidfile;
   my $waited  = 0;

   while (!$pidfile->exists || $pidfile->is_empty) {
      nap $self->nap_time;
      $waited += $self->nap_time;
      throw 'File [_1] contains no process id', [$pidfile]
         if $waited > $self->max_pidfile_wait;
   }

   my $pid = $pidfile->chomp->getline || UNDEFINED_RV;

   $pidfile->close;

   return $pid;
}

sub _execute_coderef {
   my $self = shift;
   my ($code, @args) = @{$self->cmd};
   my $rv;

   try {
      local $SIG{INT} = sub { $self->_shutdown };

      $rv = $code->($self, @args);
      $rv = $rv << 8 if defined $rv;
      $self->pidfile->unlink if $self->pidfile->exists;
   }
   catch {
      $rv = $_->rv if blessed $_ and $_->can('rv');
      emit_to \*STDERR, $_;
   };

   _exit $rv // OK;
}

sub _wait_for_child {
   my ($self, $pid, $pipes) = @_;

   my ($filtered, $stderr, $stdout) = (NUL, NUL, NUL);

   my $in_fh    = $pipes->[0]->[1];
   my $out_fh   = $pipes->[1]->[0];
   my $err_fh   = $pipes->[2]->[0];
   my $stat_fh  = $pipes->[3]->[0];
   my $err_hand = _err_handler($self->err, \$filtered, \$stderr);
   my $out_hand = _out_handler($self->out, \$filtered, \$stdout);
   my $prog     = basename(my $cmd = $self->cmd->[0]);

   try {
      if (my $tmout = $self->timeout) {
         local $SIG{ALRM} = sub { throw TimeOut, [ $prog, $tmout ] };
         alarm $tmout;
      }

      my $error = _recv_exec_failure($stat_fh);

      throw $error if $error;

      _send_in($in_fh, $self->in);
      close $in_fh;
      _drain($out_fh, $out_hand, $err_fh, $err_hand);
      waitpid $pid, 0;
      alarm 0;
   }
   catch {
      alarm 0;
      throw $_;
   };

   my $e_num = $CHILD_PID > 0 ? $CHILD_ENUM : $CHILD_ERROR;
   my $codes = $self->_return_codes_or_throw($cmd, $e_num, $stderr);

   return $self->response_class->new(
      core   => $codes->{core},
      out    => _filter_out($filtered),
      rv     => $codes->{rv},
      sig    => $codes->{sig},
      stderr => $stderr,
      stdout => $stdout,
   );
}

sub _run_cmd_using_fork_and_exec {
   my $self    = shift;
   my $pipes   = _four_nonblocking_pipe_pairs();
   my $cmd_str = _quoted_join(@{$self->cmd});

   $self->log->debug("Running ${cmd_str} using fork and exec");

   {
      local ($CHILD_ENUM, $CHILD_PID) = (0, 0);
      local $SIG{CHLD} = 'IGNORE' if $self->ignore_zombies;

      if (my $pid = fork) { # Parent
         _close_child_io($pipes);
         $pid = $self->_wait_for_pidfile_and_read if $self->detach;

         return ($self->async || $self->detach)
              ? $self->_new_async_response($pid)
              : $self->_wait_for_child($pid, $pipes);
      }
   }

   try { # Child
      my $prog = basename(my $cmd = $self->cmd->[0]);

      $self->_redirect_child_io($pipes);
      $self->_detach_process   if $self->detach;
      chdir $self->working_dir if $self->working_dir;
      $self->_execute_coderef  if is_coderef $cmd; # Never returns

      throw 'Program [_1] failed to exec: [_2]', [$prog, $OS_ERROR]
         unless exec @{$self->cmd};
   }
   catch { _send_exec_failure($pipes->[3]->[1], "${_}") };

   close $pipes->[3]->[1];
   return OK;
}

sub _run_cmd_using_ipc_run {
   my $self = shift;

   my ($buf_err, $buf_out, $error, $h, $rv) = (NUL, NUL);

   my $cmd      = $self->cmd;
   my $cmd_ref  = $self->partition_cmd ? _partition_command($cmd) : $cmd;
   my $prog     = basename($cmd->[0]);
   my $null     = devnull;
   my $in       = $self->in || 'null';
   my $out      = $self->out;
   my $err      = $self->err;
   my @cmd_args = ();

   if    (blessed $in)      { push @cmd_args, "0<${in}"       }
   elsif ($in  eq 'null')   { push @cmd_args, "0<${null}"     }
   elsif ($in  ne 'stdin')  { push @cmd_args, '0<', \$in      }

   if    (blessed $out)     { push @cmd_args, "1>${out}"      }
   elsif ($out eq 'null')   { push @cmd_args, "1>${null}"     }
   elsif ($out ne 'stdout') { push @cmd_args, '1>', \$buf_out }

   if    (blessed $err)     { push @cmd_args, "2>${err}"      }
   elsif ($err eq 'out')    { push @cmd_args, '2>&1'          }
   elsif ($err eq 'null')   { push @cmd_args, "2>${null}"     }
   elsif ($err ne 'stderr') { push @cmd_args, '2>', \$buf_err }

   my $cmd_str = _quoted_join(@{$self->cmd}, @cmd_args);

   $cmd_str .= ' &' if $self->async;
   $self->log->debug("Running ${cmd_str} using ipc run");

   try {
      if (my $tmout = $self->timeout) {
         local $SIG{ALRM} = sub { throw TimeOut, [$cmd_str, $tmout] };
         alarm $tmout;
      }

      ($rv, $h) = _ipc_run_harness($self, $cmd_ref, @cmd_args);
      alarm 0;
   }
   catch {
      alarm 0;
      throw $_;
   };

   my $sig  = $rv & 127;
   my $core = $rv & 128;

   $rv = $rv >> 8;

   if ($self->async) {
      my $pid = $self->_wait_for_pidfile_and_read;

      $out = "Started ${prog}(${pid}) in the background";

      return $self->response_class->new(
         core    => $core,
         harness => $h,
         out     => $out,
         pid     => $pid,
         rv      => $rv,
         sig     => $sig,
      );
   }

   my ($stderr, $stdout) = (NUL, NUL);

   if ($out ne 'null' and $out ne 'stdout') {
       $out = _filter_out($stdout = $buf_out) if !blessed $out;
   }
   else { $out = $stdout = NUL }

   if ($err eq 'out') {
      $stderr = $stdout;
      $error = $out;
      chomp $error;
   }
   elsif (blessed $err) {
      $stderr = $error = $err->all;
      chomp $error;
   }
   elsif ($err ne 'null' and $err ne 'stderr') {
      $stderr = $error = $buf_err;
      chomp $error;
   }
   else { $stderr = $error = NUL }

   if ($rv > $self->expected_rv) {
      $error = $error ? "${error} rv ${rv}" : "Unknown error rv ${rv}";
      $self->log->debug($error);
      throw $error, out => $out, rv => $rv;
   }

   return $self->response_class->new(
      core   => $core,
      out    => "${out}",
      rv     => $rv,
      sig    => $sig,
      stderr => $stderr,
      stdout => $stdout,
   );
}

sub _run_cmd_using_open3 { # Robbed in part from IPC::Cmd
   my ($self, $cmd) = @_;

   my ($filtered, $stderr, $stdout) = (NUL, NUL, NUL);

   my $err_hand = _err_handler($self->err, \$filtered, \$stderr);
   my $out_hand = _out_handler($self->out, \$filtered, \$stdout);

   $self->log->debug("Running ${cmd} using open3");

   my $e_num;

   {
      local ($CHILD_ENUM, $CHILD_PID) = (0, 0);

      try {
         local $SIG{PIPE} = \&_pipe_handler;

         if (my $tmout = $self->timeout) {
            local $SIG{ALRM} = sub { throw TimeOut, [$cmd, $tmout] };
            alarm $tmout;
         }

         my ($pid, $in_fh, $out_fh, $err_fh) = _open3($cmd);

         _send_in($in_fh, $self->in);
         close $in_fh;
         _drain($out_fh, $out_hand, $err_fh, $err_hand);
         waitpid $pid, 0 if $pid;
         alarm 0;
      }
      catch {
         alarm 0;
         throw $_;
      };

      $e_num = $CHILD_PID > 0 ? $CHILD_ENUM : $CHILD_ERROR;
   }

   my $codes = $self->_return_codes_or_throw($cmd, $e_num, $stderr);

   return $self->response_class->new(
      core   => $codes->{core},
      out    => _filter_out($filtered),
      rv     => $codes->{rv},
      sig    => $codes->{sig},
      stderr => $stderr,
      stdout => $stdout,
   );
}

sub _run_cmd_using_system {
   my ($self, $cmd) = @_;

   my ($error, $rv);

   my $prog = basename((split SPC, $cmd)[0]);
   my $null = devnull;
   my $in   = $self->in || 'stdin';
   my $out  = $self->out;
   my $err  = $self->err;

   if ($in ne 'null' and $in ne 'stdin' and not blessed $in) {
      # Different semi-random file names in the temp directory
      my $tmp = $self->_tempfile;
      $tmp->print($in);
      $in = $tmp;
   }

   $out = $self->_tempfile
      if $out ne 'null' and $out ne 'stdout' and not blessed $out;
   $err ||= 'out' if $self->async;
   $err = $self->_tempfile
      if $err ne 'null' and $err ne 'stderr' and not blessed $err
      and $err ne 'out';

   $cmd .= $in  eq 'stdin'  ? NUL : $in  eq 'null' ? " 0<${null}" : " 0<${in}";
   $cmd .= $out eq 'stdout' ? NUL : $out eq 'null' ? " 1>${null}" : " 1>${out}";
   $cmd .= $err eq 'stderr' ? NUL : $err eq 'null' ? " 2>${null}"
                                  : $err ne 'out'  ? " 2>${err}"  : ' 2>&1';

   $cmd .= ' & echo $! 1>' . $self->pidfile->pathname if $self->async;
   $self->log->debug("Running ${cmd} using system");

   {
      local ($CHILD_ENUM, $CHILD_PID) = (0, 0);

      try {
         local $SIG{CHLD} = \&_child_handler;

         if (my $tmout = $self->timeout) {
            local $SIG{ALRM} = sub { throw TimeOut, [$cmd, $tmout] };
            alarm $tmout;
         }

         $rv = system $cmd;
         alarm 0;
      }
      catch {
         alarm 0;
         throw $_;
      };

      my $os_error = $OS_ERROR;

      $self->log->debug(
         "System rv ${rv} child pid ${CHILD_PID} error ${CHILD_ENUM}"
      );
      # On some systems the child handler reaps the child process so the system
      # call returns -1 and sets $OS_ERROR to 'No child processes'. This line
      # and the child handler code fix the problem
      $rv = $CHILD_ENUM if $rv == UNDEFINED_RV and $CHILD_PID > 0;
      throw 'Program [_1] failed to start: [_2]',
         [ $prog, $os_error ], rv => $rv if $rv == UNDEFINED_RV;
   }

   my $sig  = $rv & 127;
   my $core = $rv & 128;

   $rv = $rv >> 8;

   my ($stderr, $stdout) = (NUL, NUL);

   if ($self->async) {
      throw 'Program [_1] failed to start', [$prog], rv => $rv if $rv != 0;

      my $pid = $self->_wait_for_pidfile_and_read;

      $out = "Started ${prog}(${pid}) in the background";

      return $self->response_class->new(
         core => $core,
         out => $out,
         pid => $pid,
         rv => $rv,
         sig => $sig,
      );
   }

   if ($out ne 'stdout' and $out ne 'null' and -f $out) {
      $out = _filter_out($stdout = io($out)->slurp);
   }
   else { $out = $stdout = NUL }

   if ($err eq 'out') {
      $stderr = $stdout;
      $error = $out;
      chomp $error;
   }
   elsif ($err ne 'stderr' and $err ne 'null' and -f $err) {
      $stderr = $error = io($err)->slurp;
      chomp $error;
   }
   else { $stderr = $error = NUL }

   if ($rv > $self->expected_rv) {
      $error = $error ? "${error} rv ${rv}" : "Unknown error rv ${rv}";
      $self->log->debug($error);
      throw $error, out => $out, rv => $rv;
   }

   return $self->response_class->new(
      core   => $core,
      out    => "${out}",
      rv     => $rv,
      sig    => $sig,
      stderr => $stderr,
      stdout => $stdout,
   );
}

sub _run_cmd { # Select one of the implementations
   my $self = shift;
   my $has_meta = _has_shell_meta(my $cmd = $self->cmd);

   if (is_arrayref $cmd) {
      throw Unspecified, ['command'] unless $cmd->[0];

      if ((is_win32 || $has_meta || $self->use_ipc_run)
          && can_load( modules => { 'IPC::Run' => '0.84' } )) {
         return $self->_run_cmd_using_ipc_run;
      }

      unless (is_win32 || $has_meta || $self->use_system) {
         return $self->_run_cmd_using_fork_and_exec;
      }

      $cmd = _quoted_join(@{$cmd});
   }

   if (!is_win32 && ($has_meta || $self->async || $self->use_system)) {
      return $self->_run_cmd_using_system($cmd);
   }

   return $self->_run_cmd_using_open3($cmd);
}


# Private functions
sub _child_handler {
   local $OS_ERROR; # So that waitpid does not step on existing value

   while ((my $child_pid = waitpid -1, WNOHANG) > 0) {
      if (WIFEXITED($CHILD_ERROR) and $child_pid > ($CHILD_PID || 0)) {
         $CHILD_PID = $child_pid;
         $CHILD_ENUM = $CHILD_ERROR;
      }
   }

   $SIG{CHLD} = \&_child_handler; # In case of unreliable signals
   return;
}

sub _close_child_io { # In the parent, close the child end of the pipes
   my $pipes = shift;

   close $pipes->[0]->[0]; undef $pipes->[0]->[0];
   close $pipes->[1]->[1]; undef $pipes->[1]->[1];
   close $pipes->[2]->[1]; undef $pipes->[2]->[1];
   close $pipes->[3]->[1]; undef $pipes->[3]->[1];
   return;
}

sub _drain { # Suck up the output from the child process
   my $selector = IO::Select->new();
   my $i = 0;
   my (%hands, @ready);

   while (defined (my $fh = $_[$i])) {
      $selector->add($fh);
      $hands{fileno $fh} = $_[$i + 1];
      $i += 2;
   }

   while (@ready = $selector->can_read) {
      for my $fh (@ready) {
         my $buf;
         my $bytes_read = sysread $fh, $buf, 64 * 1024;

         if ($bytes_read) { $hands{fileno $fh}->("${buf}") }
         else {
            $selector->remove($fh);
            close $fh;
         }
      }
   }

   return;
}

sub _err_handler {
   my ($err, $filtered, $standard) = @_;

   return sub {
      my $buf = shift;

      return unless defined $buf;

      $err->append($buf) if blessed $err;
      ${$filtered} .= $buf if $err eq 'out';
      ${$standard} .= $buf if $err ne 'null';
      emit_to \*STDERR, $buf if $err eq 'stderr';
      return;
   }
};

sub _filter_out {
   return join "\n", map    { strip_leader $_ }
                     grep   { not m{ (?: Started | Finished ) }msx }
                     split m{ [\n] }msx, $_[0];
}

sub _four_nonblocking_pipe_pairs {
   return [ nonblocking_write_pipe_pair, nonblocking_write_pipe_pair,
            nonblocking_write_pipe_pair, nonblocking_write_pipe_pair ];
}

sub _has_shell_meta {
   return (is_arrayref $_[0] && is_member '|',  $_[0]) ? TRUE
        : (is_arrayref $_[0] && is_member '&&', $_[0]) ? TRUE
        : (                         is_arrayref $_[0]) ? FALSE
        : (                    $_[0] =~ m{ [|]    }mx) ? TRUE
        : (                    $_[0] =~ m{ [&][&] }mx) ? TRUE
                                                       : FALSE;
}

sub _make_socket_pipe {
   socketpair($_[0], $_[1], AF_UNIX, SOCK_STREAM, PF_UNSPEC)
      or throw $EXTENDED_OS_ERROR;
   shutdown($_[0], 1);  # No more writing for reader
   shutdown($_[1], 0);  # No more reading for writer
   return;
}

sub _open3 {
   local (*TO_CHLD_R,     *TO_CHLD_W);
   local (*FR_CHLD_R,     *FR_CHLD_W);
   local (*FR_CHLD_ERR_R, *FR_CHLD_ERR_W);

   _make_socket_pipe(*TO_CHLD_R,     *TO_CHLD_W    );
   _make_socket_pipe(*FR_CHLD_R,     *FR_CHLD_W    );
   _make_socket_pipe(*FR_CHLD_ERR_R, *FR_CHLD_ERR_W);

   my $pid = open3('>&TO_CHLD_R', '<&FR_CHLD_W', '<&FR_CHLD_ERR_W', @_);

   return ($pid, *TO_CHLD_W, *FR_CHLD_R, *FR_CHLD_ERR_R);
}

sub _out_handler {
   my ($out, $filtered, $standard) = @_;

   return sub {
      my $buf = shift;

      return unless defined $buf;

      $out->append($buf) if blessed $out;
      ${$filtered} .= $buf if $out ne 'null';
      ${$standard} .= $buf if $out ne 'null';
      emit_to \*STDOUT, $buf if $out eq 'stdout';
      return;
   }
}

sub _partition_command {
   my $cmd = shift;
   my $aref = [];
   my @command = ();

   for my $item (grep { defined && length } @{$cmd}) {
      if ($item !~ m{ [^\\][\<\>\|\&] }mx) { push @{$aref}, $item }
      else {
         push @command, $aref, $item;
         $aref = [];
      }
   }

   if ($aref->[0]) {
      if ($command[0]) { push @command, $aref }
      else { @command = @{$aref} }
   }

   return \@command;
}

sub _pipe_handler {
   local $OS_ERROR; # So that wait does not step on existing value

   $CHILD_PID = wait;
   $CHILD_ENUM = (255 << 8) + 13;
   $SIG{PIPE} = \&_pipe_handler;
   return;
}

sub _quote {
   my $v = shift; return is_win32 ? '"'.$v.'"' : "'${v}'";
}

sub _quoted_join {
   return join SPC, map { m{ [ ] }mx ? _quote->($_) : $_ } @_;
}

sub _recv_exec_failure {
   my $fh = shift;
   my $to_read = 2 * length pack 'I', 0;

   read $fh, my $buf = NUL, $to_read or return FALSE;

   (my $errno, $to_read) = unpack 'II', $buf;

   $ERRNO = $errno;
   read $fh, my $error = NUL, $to_read;
   utf8::decode $error if $error;

   return $error || "${ERRNO}";
}

sub _redirect_stderr {
   my $v = shift;
   my $err = \*STDERR; close $err;
   my $op = openhandle $v ? '>&' : '>';
   my $sink = $op eq '>' ? $v : fileno $v;

   throw "Could not redirect STDERR to ${sink}: ${OS_ERROR}"
      unless open $err, $op, $sink;
   return;
}

sub _redirect_stdin {
   my $v = shift;
   my $in = \*STDIN; close $in;
   my $op = openhandle $v ? '<&' : '<';
   my $src = $op eq '<' ? $v : fileno $v;

   throw "Could not redirect STDIN from ${src}: ${OS_ERROR}"
      unless open $in,  $op, $src;
   return;
}

sub _redirect_stdout {
   my $v = shift;
   my $out = \*STDOUT; close $out;
   my $op = openhandle $v ? '>&' : '>';
   my $sink = $op eq '>' ? $v : fileno $v;

   throw "Could not redirect STDOUT to ${sink}: ${OS_ERROR}"
      unless open $out, $op, $sink;
   return;
}

sub _send_exec_failure {
   my ($fh, $error) = @_;

   utf8::encode $error;
   emit_to $fh, pack 'IIa*', 0+$ERRNO, length $error, $error;
   close $fh;
   _exit 255;
}

sub _send_in {
   my ($fh, $in) = @_;

   return unless $in;

   if (blessed $in) { emit_to $fh, $in->slurp }
   elsif ($in ne 'null' and $in ne 'stdin') { emit_to $fh, $in }

   return;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

Passing a logger object reference in with the C<log> attribute will cause
the C<run_cmd> method to log at the debug level

=head1 Dependencies

=over 3

=item L<Class::Null>

=item L<File::DataClass>

=item L<Module::Load::Conditional>

=item L<Moo>

=item L<Sub::Install>

=item L<Try::Tiny>

=item L<Unexpected>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-Usul.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

L<MooseX::Daemonize> - Stole some code from that module

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2023 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
