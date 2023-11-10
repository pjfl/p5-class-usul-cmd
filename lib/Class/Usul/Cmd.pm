package Class::Usul::Cmd;

use 5.010001;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 5 $ =~ /\d+/gmx );

use Class::Usul::Cmd::Constants qw( TRUE );
use Class::Usul::Cmd::Types     qw( ConfigProvider Logger );
use Class::Usul::Cmd::Util      qw( merge_attributes );
use Moo;
use Class::Usul::Cmd::Options;

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

Defines the following attributes;

=over 3

=item C<config>

A required object reference used to provide configuration attributes. See
the L<config provider|Class::Usul::Cmd::Types/ConfigProvider> type

=cut

has 'config' => is => 'ro', isa => ConfigProvider, required => TRUE;

=item C<log>

An optional object reference used to log text messages. See the
L<logger|Class::Usul::Cmd::Types/Logger> type

=item C<has_log>

Predicate

=cut

has 'log' => is => 'ro', isa => Logger, predicate => 'has_log';

with 'Class::Usul::Cmd::Trait::IPC';
with 'Class::Usul::Cmd::Trait::L10N';
with 'Class::Usul::Cmd::Trait::OutputLogging';
with 'Class::Usul::Cmd::Trait::Prompting';
with 'Class::Usul::Cmd::Trait::DebugFlag';
with 'Class::Usul::Cmd::Trait::Usage';
with 'Class::Usul::Cmd::Trait::RunningMethods';

=back

=head1 Subroutines/Methods

=over 3

=item C<BUILDARGS>

If the constructor is called with a C<builder> attribute (either an object
reference or a hash reference) it's C<config>, C<l10n>, and C<log> attributes
are used to instantiate the attributes of the same name in this class

=cut

around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_;

   my $attr    = $orig->($self, @args);
   my $builder = $attr->{builder};

   merge_attributes $attr, $builder, [qw(config l10n log)] if $builder;

   return $attr;
};

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moo>

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

Peter Flanigan, C<< <lazarus@roxsoft.co.uk> >>

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
