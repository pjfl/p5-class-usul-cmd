package Class::Usul::Cmd::Constants;

use strictures;
use parent 'Exporter::Tiny';

use Class::Usul::Cmd::Exception;
use Ref::Util qw( is_arrayref );

our @EXPORT = qw( BRK DOT DEFAULT_ENCODING DUMP_EXCEPT EXCEPTION_CLASS FAILED
                  FALSE LOG_LEVELS NO NUL OK QUIT QUOTED_RE SPC TRUE
                  UNDEFINED_RV UNTAINT_CMDLINE UNTAINT_IDENTIFIER UNTAINT_PATH
                  WIDTH YES );

=pod

=encoding utf-8

=head1 Name

Class::Usul::Cmd::Constants - Definitions of constant values

=head1 Synopsis

   use Class::Usul::Constants qw( FALSE SEP TRUE );

   my $bool = TRUE;
   my $space = SPC;

=head1 Description

Exports a list of subroutines each of which returns a constants value

=head1 Configuration and Environment

Defines the following class attributes;

=over 3

=item C<Dump_Except>

List of methods to exclude from dumping out when introspecting objects

=cut

my $Dump_Except = [
   qw( BUILDARGS BUILD DOES after around before extends has new with )
];

sub Dump_Except {
   my ($class, $methods) = @_;

   return $Dump_Except unless defined $methods;

   return $Dump_Except = $methods;
}

=item C<Exception_Class>

Defaults to the exception class in this distribution

=cut

my $Exception_Class = 'Class::Usul::Cmd::Exception';

sub Exception_Class {
   my ($self, $class) = @_;

   return $Exception_Class unless defined $class;

   $Exception_Class->throw(
      "Exception class ${class} is not loaded or has no throw method"
   ) unless $class->can('throw');

   return $Exception_Class = $class;
}

=item C<Log_Levels>

List of methods the logging object must support

=cut

my $Log_Levels = [ qw( alert debug error fatal info warn ) ];

sub Log_Levels {
   my ($self, $levels) = @_;

   return $Log_Levels unless defined $levels;

   EXCEPTION_CLASS->throw(
      "Log levels must be an array reference with one defined value"
   ) unless is_arrayref $levels and defined $levels->[0];

   return $Log_Levels = $levels;
}

=back

These are accessor/mutators for class attributes of the same name. The
constants with uppercase names return these values. At compile time they
can be used to set values that are then constant at runtime

=head1 Subroutines/Methods

=over 3

=item C<BRK>

Separate leader from message with the characters colon space

=cut

sub BRK () { ': ' }

=item C<DOT>

Literal period character

=cut

sub DOT () { q(.) }

=item C<DEFAULT_ENCODING>

String C<UTF-8>

=cut

sub DEFAULT_ENCODING () { 'UTF-8' }

=item C<DUMP_EXCEPT>

Do not dump these symbols when introspecting objects

=cut

sub DUMP_EXCEPT () { @{ __PACKAGE__->Dump_Except } }

=item C<EXCEPTION_CLASS>

The name of the class used to throw exceptions. Defaults to
L<Class::Usul::Exception> but can be changed by setting the
C<Exception_Class> class attribute

=cut

sub EXCEPTION_CLASS () { __PACKAGE__->Exception_Class }

=item C<FAILED>

Non zero exit code indicating program failure

=cut

sub FAILED () { 1 }

=item C<FALSE>

Digit zero

=cut

sub FALSE () { 0 }

=item C<LOG_LEVELS>

List of methods the log object is expected to support. Returns the value
of the C<Log_Levels> class method

=cut

sub LOG_LEVELS () { @{ __PACKAGE__->Log_Levels } }

=item C<NO>

The letter C<n>

=cut

sub NO () { 'n' }

=item C<NUL>

Empty (zero length) string

=cut

sub NUL () { q() }

=item C<OK>

Returns good program exit code, zero

=cut

sub OK () { 0 }

=item C<QUIT>

The character q

=cut

sub QUIT () { 'q' }

=item C<QUOTED_RE>

The regular expression to match a quoted string. Lifted from L<Regexp::Common>
which now has installation and indexing issues

=cut

sub QUOTED_RE () { qr{ (?:(?:\")(?:[^\\\"]*(?:\\.[^\\\"]*)*)(?:\")|(?:\')(?:[^\\\']*(?:\\.[^\\\']*)*)(?:\')|(?:\`)(?:[^\\\`]*(?:\\.[^\\\`]*)*)(?:\`)) }mx }

=item C<SPC>

Space character

=cut

sub SPC () { q( ) }

=item C<TRUE>

Digit C<1>

=cut

sub TRUE () { 1 }

=item C<UNDEFINED_RV>

Digit C<-1>. Indicates that a method wrapped in a try/catch block failed
to return a defined value

=cut

sub UNDEFINED_RV () { -1 }

=item C<UNTAINT_CMDLINE>

Regular expression used to untaint command line strings

=cut

sub UNTAINT_CMDLINE () { qr{ \A ([^\$&;<>\`|]+) \z }mx }

=item C<UNTAINT_IDENTIFIER>

Regular expression used to untaint identifier strings

=cut

sub UNTAINT_IDENTIFIER () { qr{ \A ([a-zA-Z0-9_]+) \z }mx }

=item C<UNTAINT_PATH>

Regular expression used to untaint path strings

=cut

sub UNTAINT_PATH () { qr{ \A ([^\$%&\*;<>\`|]+) \z }mx }

=item C<WIDTH>

Default terminal screen width in characters

=cut

sub WIDTH () { 80 }

=item C<YES>

The character C<y>

=cut

sub YES () { 'y' }

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Exporter::Tiny>

=item L<Class::Usul::Cmd::Exception>

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
