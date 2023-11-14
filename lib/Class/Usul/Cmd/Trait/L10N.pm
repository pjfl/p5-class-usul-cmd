package Class::Usul::Cmd::Trait::L10N;

use Class::Usul::Cmd::Types qw( Localiser );
use Ref::Util               qw( is_arrayref );
use Unexpected::Functions   qw( inflate_placeholders );
use Moo::Role;

=pod

=encoding utf-8

=head1 Name

Class::Usul::Cmd::Trait::L10N - Localise text strings

=head1 Synopsis

   use Moo;

   with 'Class::Usul::Cmd::Trait::L10N';


=head1 Description

Localise text strings

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<l10n>

An optional object reference used to localise text messages.  See the
L<localiser|Class::Usul::Cmd::Types/Localiser> type

=item C<has_l10n>

Predicate

=cut

has 'l10n' => is => 'ro', isa => Localiser, predicate => 'has_l10n';

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<localize>

   $localized_text = $self->localize( $message, \%opts );

Localises the message. Calls the L<localiser|Class::Usul::Cmd/l10n>. The
domains to search are in the C<l10n_domains> configuration attribute. Adds
C<< $self->locale >> to the arguments passed to C<localizer>

=cut

sub localize {
   my ($self, $key, $args) = @_;

   return $self->l10n->localize($key, $args) if $self->has_l10n;

   return $key unless defined $key;

   my $text = "${key}"; chomp $text;

   $args //= {};

   if (defined $args->{params} && is_arrayref $args->{params}) {
      return $text if 0 > index $text, '[_';

      my $defaults = [ '[?]', '[]', $args->{no_quote_bind_values}];
      # Expand positional parameters of the form [_<n>]
      return inflate_placeholders $defaults, $text, @{$args->{params}};
   }

   return $text if 0 > index $text, '{';

   # Expand named parameters of the form {param_name}
   my %args = %{$args};
   my $re   = join '|', map { quotemeta $_ } keys %args;

   $text =~ s{ \{($re)\} }{ defined $args{$1} ? $args{$1} : "{${1}?}" }egmx;

   return $text;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

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
