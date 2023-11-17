package Class::Usul::Cmd::Types;

use strictures;

use Class::Usul::Cmd::Constants qw( DEFAULT_ENCODING FALSE
                                    LOG_LEVELS NUL TRUE );
use Class::Usul::Cmd::Util      qw( untaint_cmdline );
use Encode                      qw( find_encoding );
use Scalar::Util                qw( blessed tainted );
use Unexpected::Functions       qw( inflate_message );
use Try::Tiny;

use Type::Library -base, -declare =>
   qw( ConfigProvider DataEncoding Localiser Logger ProcessComms );
use Type::Utils
   qw( as class_type coerce extends from message subtype via where );

use namespace::clean -except => 'meta';

BEGIN { extends 'Unexpected::Types' };

=pod

=encoding utf-8

=head1 Name

Class::Usul::Cmd::Types - Defines type constraints

=head1 Synopsis

   use Class::Usul::Cmd::Types q(:all);

=head1 Description

Defines the following type constraints;

=over 3

=item C<ConfigProvider>

Subtype of I<Object> can be coerced from a hash reference

=cut

subtype ConfigProvider, as Object,
   where   { _has_min_config_attributes($_) },
   message { _error_for_configprovider($_) };

=item C<DataEncoding>

Subtype of C<Str> which has to be one of the list of encodings in the
L<ENCODINGS|Class::Usul::Cmd::Constants/ENCODINGS> constant

=cut

subtype DataEncoding, as Str,
   where   { _isa_untainted_encoding($_) },
   message { inflate_message 'String [_1] is not a valid encoding', $_ };

coerce DataEncoding,
   from Str,   via { untaint_cmdline $_ },
   from Undef, via { DEFAULT_ENCODING };

=item C<Localiser>

Duck type that can; C<localize>

=cut

subtype Localiser, as Object,
   where   { $_->can('localize') },
   message { _error_for_localiser($_) };

=item C<Logger>

Subtype of I<Object> which has to implement all of the methods in the
L<LOG_LEVELS|Class::Usul::Cmd::Constants/LOG_LEVELS> constant

=cut

subtype Logger, as Object,
   where   { $_->isa('Class::Null') || _has_log_level_methods($_) },
   message { _error_for_logger($_) };

=item C<ProcComms>

Duck type that can; C<run_cmd>

=cut

subtype ProcessComms, as Object,
   where   { $_->can('run_cmd') },
   message { _error_for_proc_runner($_) };

# Private functions
sub _error_for_object_reference {
   return inflate_message 'String [_1] is not an object reference', $_[0];
}

sub _error_for_configprovider {
   return _error_for_object_reference($_[0]) unless $_[0] and blessed $_[0];

   return inflate_message
      'Object [_1] is missing some configuration attributes', blessed $_[0];
}

sub _error_for_localiser {
   return _error_for_object_reference($_[0]) unless $_[0] and blessed $_[0];

   return inflate_message
      'Object [_1] is missing the "localize" method', blessed $_[0];
}

sub _error_for_logger {
   return _error_for_object_reference($_[0]) unless $_[0] and blessed $_[0];

   return inflate_message
      'Object [_1] is missing a log level method', blessed $_[0];
}

sub _error_for_proc_runner {
   return _error_for_object_reference($_[0]) unless $_[0] and blessed $_[0];

   return inflate_message
      'Object [_1] is missing the "run_cmd" method', blessed $_[0];

}

sub _has_log_level_methods {
   my $obj = shift;

   $obj->can($_) or return FALSE for (LOG_LEVELS);

   return TRUE;
}

sub _has_min_config_attributes {
   my $obj = shift;
   my @config_attr = (qw(appclass));

   $obj->can($_) or return FALSE for (@config_attr);

   return TRUE;
}

sub _isa_untainted_encoding {
   my $enc = shift;
   my $res;

   try   { $res = !tainted($enc) && find_encoding($enc) ? TRUE : FALSE }
   catch { $res = FALSE };

   return $res
}

1;

__END__

=back

=head1 Subroutines/Methods

None

=head1 Configuration and Environment

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Cmd::Constants>

=item L<Class::Usul::Cmd::Util>

=item L<Type::Tiny>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.  Please report problems to the address
below.  Patches are welcome

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 Acknowledgements

Larry Wall - For the Perl programming language

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
