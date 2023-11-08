package Class::Usul::Cmd::Exception;

use Unexpected::Functions qw( has_exception );
use Unexpected::Types     qw( Int Str );
use Moo;

extends q(Unexpected);
with    q(Unexpected::TraitFor::ErrorLeader);
with    q(Unexpected::TraitFor::ExceptionClasses);

my $class = __PACKAGE__;

$class->ignore_class('Class::Usul::Cmd::IPC::Runtime', 'Sub::Quote');

=pod

=encoding utf8

=head1 Name

Class::Usul::Cmd::Exception - Exception handling

=head1 Synopsis

   use Class::Usul::Cmd::Util qw(throw);
   use Try::Tiny;

   sub some_method {
      my $self = shift;

      try   { this_will_fail }
      catch { throw $_ };
   }

   # OR
   use Class::Usul::Cmd::Util qw(throw_on_error);

   sub some_method {
      my $self = shift;

      eval { this_will_fail };
      throw_on_error;
   }

   # THEN
   try   { $self->some_method() }
   catch { warn $_."\n\n".$_->stacktrace."\n" };

=head1 Description

An exception class that supports error messages with placeholders, a L</throw>
method with automatic re-throw upon detection of self, conditional throw if an
exception was caught and a simplified stack trace

Error objects are overloaded to stringify to the full error message plus a
leader

=head1 Configuration and Environment

The C<< __PACKAGE__->ignore_class >> class method contains a classes
whose presence should be ignored by the error message leader

Defines the following list of read only attributes;

=over 3

=item C<class>

Defaults to C<__PACKAGE__>. Can be used to differentiate different classes of
error

=cut

has '+class' => default => $class;

=item C<out>

Defaults to null. May contain the output from whatever just threw the
exception

=cut

has 'out' => is => 'ro', isa => Str, default => q();

=item C<rv>

Return value which defaults to one

=cut

has 'rv' => is => 'ro', isa => Int, default => 1;

=item C<time>

A positive integer which defaults to the C<CORE::time> the exception was
thrown

=cut

has 'time' =>
   is       => 'ro',
   isa      => Int,
   default  => CORE::time(),
   init_arg => undef;

=back

=head1 Exceptions

Defines the following list of exceptions;

=over 3

=item C<Class::Usul::Cmd::Exception>

Parent for the other exceptions defined here

=cut

has_exception $class;

=item C<DateTimeCoercion>

Failure to coerce a Unix time value from a string

=cut

has_exception 'DateTimeCoercion' => parents => [ $class ],
   error   => 'String [_1] will not coerce to a Unix time value';

=item C<Tainted>

The string is possibly tainted

=cut

has_exception 'Tainted' => parents => [ $class ],
   error   => 'String [_1] contains possible taint';

=item C<TimeOut>

A time out occurred

=cut

has_exception 'TimeOut' => parents => [ $class ],
   error   => 'Command [_1] timed out after [_2] seconds';

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moo>

=item L<Unexpected>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.  Please report problems to the address
below.  Patches are welcome

=head1 Author

Peter Flanigan C<< <pjfl@cpan.org> >>

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
