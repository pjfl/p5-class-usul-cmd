package Class::Usul::Cmd::Trait::RunExternal;

use Class::Usul::Cmd::Constants qw( EXCEPTION_CLASS );
use Class::Usul::Cmd::Types     qw( LoadableClass );
use Class::Usul::Cmd::Util      qw( arg_list throw );
use Unexpected::Functions       qw( Unspecified );
use Moo::Role;

requires qw( config log );

=pod

=encoding utf-8

=head1 Name

Class::Usul::Cmd::Trait::RunExternal - Run external commands

=head1 Synopsis

   use Moo;

   extends 'Class::Usul::Cmd';
   with    'Class::Usul::Cmd::Trait::RunExternal';

=head1 Description

Runs external commands

=head1 Configuration and Environment

Defines no public attributes

=over 3

=cut

# Private attributes
has '_ipc_runtime_class' =>
   is      => 'lazy',
   isa     => LoadableClass,
   default => 'Class::Usul::Cmd::IPC::Runtime';

=back

=head1 Subroutines/Methods

=over 3

=item C<run_cmd>

   $response = $self->run_cmd( $cmd, $opts );

Runs the given command. If C<$cmd> is a string then an implementation based on
the L<IPC::Open3> function is used. If C<$cmd> is an array reference then an
implementation using C<fork> and C<exec> in L<Class::Usul::Cmd::IPC::Runtime>
is used to execute the command. If the command contains pipes then an
implementation based on L<IPC::Run> is used if it is installed. If L<IPC::Run>
is not installed then the arrayref is joined with spaces and the C<system>
implementation is used. The C<$opts> hash reference and the C<$response> object
are described in L<Class::Usul::Cmd::IPC::Runtime>

=cut

sub run_cmd {
   my ($self, $cmd, @args) = @_;

   my $attr   = arg_list @args;
   my $config = $self->config;

   $attr->{cmd}       = $cmd or throw Unspecified, ['command'];
   $attr->{log}     //= $self->log if $self->log;
   $attr->{rundir}  //= $config->rundir if $config->can('rundir');
   $attr->{tempdir} //= $config->tempdir if $config->can('tempdir');

   return $self->_ipc_runtime_class->new($attr)->run_cmd;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Cmd::IPC::Runtime>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.  Please report problems to the address
below.  Patches are welcome

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
