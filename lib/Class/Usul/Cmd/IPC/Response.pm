package Class::Usul::Cmd::IPC::Response;

use Class::Usul::Cmd::Types qw( Int Object Str Undef );
use Moo;

=pod

=head1 Name

Class::Usul::Cmd::IPC::Response - Response class for running external programs

=head1 Synopsis

   use Class::Usul::Cmd::IPC::Response;

   my $result = Class::Usul::Cmd::IPC::Response->new();

=head1 Description

Response class returned by L<Class::Usul::Cmd::IPC::Runtime/run_cmd> and
L<Class::Usul::Cmd::IPC::Runtime/popen>

=head1 Configuration and Environment

This class defined these attributes:

=over 3

=item C<core>

True if external commands core dumped

=cut

has 'core' => is => 'ro', isa => Int, default => 0;

=item C<harness>

The L<IPC::Run> harness object if one was used

=cut

has 'harness' => is => 'ro', isa => Object | Undef;

=item C<out>

Processed output from the command

=cut

has 'out' => is => 'ro', isa => Str, default => q();

=item C<pid>

The id of the child process

=cut

has 'pid' => is => 'ro', isa => Int | Undef;

=item C<rv>

The return value of from running the command

=cut

has 'rv' => is => 'ro', isa => Int, default => 0;

=item C<sig>

Signal that caused the program to terminate

=cut

has 'sig' => is => 'ro', isa => Int | Undef;

=item C<stderr>

The standard error output from the command

=cut

has 'stderr' => is => 'ro', isa => Str, default => q();

=item C<stdout>

The standard output from the command

=cut

has 'stdout' => is => 'ro', isa => Str, default => q();

use namespace::autoclean;

1;

__END__

=back

=head1 Subroutines/Methods

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moo>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

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
