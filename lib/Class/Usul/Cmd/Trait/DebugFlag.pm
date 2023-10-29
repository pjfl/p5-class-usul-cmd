package Class::Usul::Cmd::Trait::DebugFlag;

use Class::Usul::Cmd::Constants qw( FALSE TRUE );
use Class::Usul::Cmd::Util      qw( ns_environment );
use Class::Usul::Cmd::Types     qw( Bool );
use Moo::Role;
use Class::Usul::Cmd::Options;

requires qw( config is_interactive yorn );

=pod

=encoding utf-8

=head1 Name

Class::Usul::Cmd::Trait::DebugFlag - Handles the state of the debug flag

=head1 Synopsis

   use Moo;

   extends 'Class::Usul::Cmd';
   with    'Class::Usul::Cmd::Trait::DebugFlag';

=head1 Description

Handles the state of the debug flag

=head1 Configuration and Environment

Defines the following command line options;

=over 3

=item C<D debug>

Turn debugging on

=cut

option 'debug' =>
   is            => 'rwp',
   isa           => Bool,
   default       => sub {
      return !!ns_environment($_[0]->config->appclass, 'debug') ? TRUE : FALSE;
   },
   documentation => 'Turn debugging on. Prompts if interactive',
   lazy          => TRUE,
   short         => 'D';

=item C<n noask>

Do not prompt to turn debugging on

=cut

option 'noask' =>
   is             => 'ro',
   isa            => Bool,
   default        => FALSE,
   documentation  => 'Do not prompt for debugging',
   short          => 'n';

=back

=head1 Subroutines/Methods

=over 3

=cut

around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_;

   my $attr = $orig->($self, @args);
   my $deprecated = delete $attr->{nodebug};

   $attr->{noask} //= $deprecated;
   return $attr;
};

=item C<BUILD>

Called just after the object is constructed this method handles prompting for
the debug state if it is an interactive session. Also offers the option to quit

=cut

sub BUILD { # Must not call logger before this executes
   my $self = shift;

   $self->_set_debug($self->_get_debug_option);
   return;
}

=item C<debug_flag>

   $cmd_line_option = $self->debug_flag

Returns the command line debug flag to match the current debug state

=cut

sub debug_flag {
   my $self = shift; return $self->debug ? '-D' : '-n';
}

# Private methods
sub _dont_ask {
   my $self = shift; return $self->debug || !$self->is_interactive();
}

sub _get_debug_option {
   my $self = shift;

   return $self->debug if $self->noask or $self->_dont_ask;

   return $self->yorn('Do you want debugging turned on', FALSE, TRUE);
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

=item L<Moo::Role>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-Usul-Cmd.
Patches are welcome

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
