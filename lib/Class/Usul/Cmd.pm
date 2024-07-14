package Class::Usul::Cmd;

use 5.010001;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 14 $ =~ /\d+/gmx );

use Moo;
use Class::Usul::Cmd::Options;

with 'Class::Usul::Cmd::Trait::Base';
with 'Class::Usul::Cmd::Trait::RunExternal';
with 'Class::Usul::Cmd::Trait::OutputLogging';
with 'Class::Usul::Cmd::Trait::Prompting';
with 'Class::Usul::Cmd::Trait::DebugFlag';
with 'Class::Usul::Cmd::Trait::Usage';
with 'Class::Usul::Cmd::Trait::RunningMethods';

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

Class::Usul::Cmd - Command line support framework

=head1 Synopsis

   package Test;

   our $VERSION = 0.1;

   use Moo;
   use Class::Usul::Cmd::Options;

   extends 'Class::Usul::Cmd';

   option 'test_attr' => is => 'ro';

   sub test_method : method {
   }

   ...

   # In bin/test_script
   exit Test->new_with_options(config => Test::Config->new())->run;

   ...

   bin/test_script --test-attr foo test-method

=head1 Description

Command line support framework

=head1 Configuration and Environment

Defines no public attributes

=head1 Subroutines/Methods

Defines no public methods

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moo>

=item L<Class::Usul::Cmd::Options>

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
