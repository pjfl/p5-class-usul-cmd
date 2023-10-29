package Class::Usul::Cmd::Getopt;

use strictures;
use parent 'Getopt::Long::Descriptive';

use Class::Usul::Cmd::Getopt::Usage;
use Getopt::Long 2.38;

sub usage_class {
   return 'Class::Usul::Cmd::Getopt::Usage';
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

Class::Usul::Cmd::Getopt - Getopt::Long but simpler more powerful and flexible

=head1 Synopsis

   use Class::Usul::Cmd::Getopt qw( describe_options );

=head1 Description

L<Getopt::Long> but simpler more powerful and flexible. Inherits from
L<Getopt::Long::Descriptive>

=head1 Configuration and Environment

Defines no attributes

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<usage_class>

Overrides the class method in the L<Getopt::Long::Descriptive> setting the
usage class to L<Class::Usul::Cmd::Getopt::Usage>

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Cmd::Getopt::Usuage>

=item L<Getopt::Long::Descriptive>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-Usul.
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
