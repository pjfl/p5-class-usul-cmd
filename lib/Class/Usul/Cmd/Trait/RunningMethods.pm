package Class::Usul::Cmd::Trait::RunningMethods;

use Class::Usul::Cmd::Constants qw( FAILED NUL OK TRUE UNDEFINED_RV );
use Class::Usul::Cmd::Types     qw( ArrayRef HashRef Int SimpleStr );
use File::DataClass::Types      qw( OctalNum );
use Class::Usul::Cmd::Util      qw( dash2under delete_tmp_files elapsed emit_to
                                    exception is_member logname throw
                                    untaint_identifier );
use English                     qw( -no_match_vars );
use Ref::Util                   qw( is_hashref );
use Scalar::Util                qw( blessed );
use Try::Tiny;
use Moo::Role;
use Class::Usul::Cmd::Options;

requires qw( app_version can_call debug error exit_usage
             extra_argv next_argv output quiet );

=pod

=encoding utf-8

=head1 Name

Class::Usul::Cmd::Trait::RunningMethods - Try and run a method catch and handle any exceptions

=head1 Synopsis

   use Moo;

   extends 'Class::Usul::Cmd';
   with    'Class::Usul::Cmd::Trait::RunningMethods';

=head1 Description

Implements the L</run> method which calls the target method in a try / catch
block. Handles any resulting exceptions

=head1 Configuration and Environment

Defines the following command line options;

=over 3

=item C<c method>

The method in the program class to dispatch to

=cut

option 'method' =>
   is            => 'rwp',
   isa           => SimpleStr,
   default       => NUL,
   documentation => 'Name of the method to call',
   format        => 's',
   order         => 1,
   short         => 'c';

=item C<o options key=value>

The method that is dispatched to can access the key/value pairs
from the C<< $self->options >> hash reference

=cut

option 'options' =>
   is            => 'ro',
   isa           => HashRef,
   default       => sub { {} },
   documentation =>
      'Zero, one or more key=value pairs available to the method call',
   format        => 's%',
   short         => 'o';

=item C<umask>

An octal number which is used to set the umask by the L</run> method

=cut

option 'umask' =>
   is            => 'rw',
   isa           => OctalNum,
   coerce        => TRUE,
   default       => sub {
      my $self = shift;

      return $self->config->can('umask') ? $self->config->umask : '027';
   },
   documentation => 'Set the umask to this octal number',
   format        => 's',
   lazy          => TRUE;

=item C<v verbose>

Repeatable boolean that increases the verbosity of the output

=cut

option 'verbose' =>
   is            => 'ro',
   isa           => Int,
   default       => 0,
   documentation => 'Increase the verbosity of the output',
   repeatable    => TRUE,
   short         => 'v';

=back

Defines the following public attributes;

=over 3

=item C<params>

A hash reference keyed by method name. The values are array references which
are flattened and passed to the method call by L</run>

=cut

has 'params' =>
   is       => 'lazy',
   isa      => HashRef[ArrayRef],
   default  => sub { {} };

=back

=head1 Subroutines/Methods

=over 3

=item C<handle_result>

   $return_value = $self->handle_result( $method, $return_value );

Handles the result of calling the command

=cut

sub handle_result {
   my ($self, $method, $rv) = @_;

   my $params      = $self->params->{$method};
   my $args        = (defined $params ) ? $params->[0] : undef;
   my $expected_rv = (is_hashref $args) ? $args->{expected_rv} // OK : OK;

   if (defined $rv and $rv <= $expected_rv) {
      $self->output('Finished in [_1] seconds', { args => [elapsed] })
         unless $self->quiet;
   }
   elsif (defined $rv and $rv > OK) {
      $self->error('Terminated code [_1]', {
         args => [$rv], no_quote_bind_values => TRUE
      });
   }
   else {
      if ($rv == UNDEFINED_RV) {
         $self->error('Terminated with undefined rv');
      }
      else {
         if (defined $rv) {
            $self->error('Method [_1] unknown rv [_2]', {
               args => [$method, $rv]
            });
         }
         else {
            $self->error('Method [_1] error uncaught or rv undefined', {
               args => [$method]
            });
            $rv = UNDEFINED_RV;
         }
      }
   }

   return $rv;
}

=item C<run>

   $exit_code = $self->run;

Call the method specified by the C<-c> option on the command
line. Returns the exit code

=cut

sub run {
   my $self   = shift;
   my $method = $self->select_method;
   my $text   = 'Started by [_1] Version [_2] Pid [_3]';
   my $args   = { args => [logname, $self->app_version, abs $PID] };

   $self->quiet(TRUE) if is_member $method, 'help', 'run_chain';
   $self->output($text, $args) unless $self->quiet;

   umask $self->umask;

   my $rv;

   if ($method eq 'run_chain' or $self->can_call($method)) {
      my $params = exists $self->params->{$method}
         ? $self->params->{$method} : [];

      try {
         $rv = $self->$method(@{$params});
         throw 'Method [_1] return value undefined',
            args => [$method], rv => UNDEFINED_RV unless defined $rv;
      }
      catch { $rv = $self->_handle_run_exception($method, $_) };
   }
   else {
      $self->error('Class [_1] method [_2] not found', {
         args => [ blessed $self, $method ]
      });
      $rv = UNDEFINED_RV;
   }

   $rv = $self->handle_result($method, $rv);
   delete_tmp_files($self);
   return $rv;
}

=item C<run_chain>

   $exit_code = $self->run_chain( $method );

Called by L</run> when L</select_method> cannot determine which method to
call. Outputs usage if C<method> is undefined. Logs an error if
C<method> is defined but not (by definition a callable method).
Returns exit code C<FAILED>

=cut

sub run_chain {
   my $self = shift;

   if ($self->method) {
      $self->error('Method [_1] unknown', { args => [$self->method] });
   }
   else { $self->error('Method not specified') }

   $self->exit_usage(0);
   return; # Not reached
}

=item C<select_method>

   $method = $self->select_method;

Called by L</run> it examines the L</method> attribute and if necessary the
extra command line arguments to determine the method to call

=cut

sub select_method {
   my $self   = shift;
   my $method = untaint_identifier dash2under $self->method;

   unless ($self->can_call($method)) {
      $method = untaint_identifier dash2under $self->extra_argv(0);

      if ($method && $self->can_call($method)) {
         $self->_set_method($method);
         $self->next_argv;
      }
      else { $method = 'run_chain' }
   }

   return $method ? $method : 'run_chain';
}

# Private methods
sub _handle_run_exception {
   my ($self, $method, $error) = @_;

   my $e;

   unless ($e = exception $error) {
      $self->error('Method [_1] exception without error', { args => [$method]});
      return UNDEFINED_RV;
   }

   $self->output($e->out) if $e->can('out') && $e->out;
   $self->error($e->error, { args => $e->args });
   _output_stacktrace($error, $self->verbose) if $self->debug;

   return $e->can('rv')
        ? ($e->rv || (defined $e->rv ? FAILED : UNDEFINED_RV)) : UNDEFINED_RV;
}

# Private functions
sub _output_stacktrace {
   my ($e, $verbose) = @_;

   $verbose //= 0;

   return unless $e and blessed $e;
   return emit_to \*STDERR, $e->trace.NUL if $verbose > 0 && $e->can('trace');

   emit_to \*STDERR, $e->stacktrace.NUL if $e->can('stacktrace');
   return;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Cmd::Options>

=item L<File::DataClass>

=item L<Moo::Role>

=item L<Try::Tiny>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-Usul-Cmd.  Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

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
