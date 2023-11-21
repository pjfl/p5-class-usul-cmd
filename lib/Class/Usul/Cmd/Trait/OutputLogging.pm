package Class::Usul::Cmd::Trait::OutputLogging;

use Class::Usul::Cmd::Constants qw( BRK FAILED FALSE NUL TRUE WIDTH );
use Class::Usul::Cmd::Types     qw( Bool SimpleStr );
use Class::Usul::Cmd::Util      qw( abs_path emit emit_err throw );
use English                     qw( -no_match_vars );
use File::Basename              qw( );
use Ref::Util                   qw( is_arrayref );
use Text::Autoformat            qw( autoformat );
use Moo::Role;
use Class::Usul::Cmd::Options;

requires qw( config localize log );

=pod

=encoding utf-8

=head1 Name

Class::Usul::Cmd::Trait::OutputLogging - Localised logging and command line output methods

=head1 Synopsis

   use Moo;

   extends 'Class::Usul::Cmd';
   with    'Class::Usul::Cmd::Trait::IPC';

=head1 Description

Localised logging and command line output methods

=head1 Configuration and Environment

Requires the following;

=over 3

=item C<config>

=item C<localize>

=item C<log>

=back

Defines the following command line options;

=over 3

=item C<L locale>

Print text and error messages in the selected language. If no language
catalogue is supplied prints text and errors in terse English. Defaults
to C<en>

=cut

option 'locale' =>
   is            => 'lazy',
   isa           => SimpleStr,
   default       => sub {
      my $self = shift;

      return $self->config->can('locale') ? $self->config->locale : 'en';
   },
   documentation => 'Loads the specified language message catalogue',
   format        => 's',
   short         => 'L';

=item C<q quiet_flag>

Quietens the usual started/finished information messages

=cut

option 'quiet' =>
   is            => 'ro',
   isa           => Bool,
   default       => FALSE,
   documentation => 'Quiet the display of information messages',
   reader        => '__quiet_flag',
   short         => 'q';

# Private attributes
has '_name' =>
   is      => 'lazy',
   isa     => SimpleStr,
   default => sub {
      my $self = shift;
      my $config = $self->config;
      my @suffixes = qw(.pm .t);

      return ucfirst $config->name if $config->can('name');

      return File::Basename::basename($config->pathname, @suffixes)
         if $config->can('pathname');

      my $name = $PROGRAM_NAME;

      $name = $EXECUTABLE_NAME if '-' eq substr $name, 0, 1;

      return File::Basename::basename($name, @suffixes);
   };

has '_quiet_flag' =>
   is      => 'rwp',
   isa     => Bool,
   builder => sub { $_[0]->__quiet_flag },
   lazy    => TRUE;

=back

=head1 Subroutines/Methods

=over 3

=item C<add_leader>

   $leader = $self->add_leader( $text, \%opts );

Prepend C<< $self->config->name >> to each line of C<$text>. If
C<< $opts->{no_lead} >> exists then do nothing. Return C<$text> with
leader prepended

=cut

sub add_leader {
   my ($self, $text, $opts) = @_;

   return NUL unless $text;

   $opts //= {};

   my $leader = $opts->{no_lead} ? NUL
      : ($opts->{name} ? $opts->{name} : $self->_name) . BRK;

   if ($opts->{fill}) {
      my $width = $opts->{width} // WIDTH;

      $text = autoformat $text, { right => $width - 1 - length $leader };
   }

   return join "\n", map { (m{ \A $leader }mx ? NUL : $leader) . $_ }
                     split  m{ \n }mx, $text;
}

=item C<error>

   $self->error( $text, \%opts );

Calls the L<localiser|Class::Usul::Cmd/l10n> with the passed options. Logs the
result at the error level, then adds the program leader and prints the result
to I<STDERR>

=cut

sub error {
   my ($self, $text, $opts) = @_;

   $text = $self->_localise($text, $opts);

   if ($self->log) {
      $self->log->error($self->add_leader($_, $opts))
         for (split m{ \n }mx, "${text}");
   }

   emit_err $self->add_leader($text, $opts);

   return TRUE;
}

=item C<fatal>

   $self->fatal( $text, \%opts );

Calls the L<localiser|Class::Usul::Cmd/l10n> with the passed options. Logs the
result at the alert level, then adds the program leader and prints the result
to I<STDERR>. Exits with a return code of one

=cut

sub fatal {
   my ($self, $text, $opts) = @_;

   my (undef, $file, $line) = caller 0;

   my $posn = ' at ' . abs_path($file) . " line ${line}";

   $text = $self->_localise($text, $opts) . $posn;

   if ($self->log) {
      $self->log->alert($self->add_leader($_, $opts))
         for (split m{ \n }mx, $text);
   }

   emit_err $self->add_leader($text, $opts);

   exit FAILED;
}

=item C<info>

   $self->info( $text, \%opts );

Calls the L<localiser|Class::Usul::Cmd/l10n> with the passed options. Logs the
result at the info level, then adds the program leader and prints the result to
I<STDOUT>

=cut

sub info {
   my ($self, $text, $opts) = @_;

   $opts //= {};
   $text = $self->_localise($text, $opts, TRUE);

   if ($self->log) {
      $self->log->info($self->add_leader($_, $opts))
         for (split m{ \n }mx, $text);
   }

   emit $self->add_leader($text, $opts) unless $self->quiet or $opts->{quiet};

   return TRUE;
}

=item C<output>

   $self->output( $text, \%opts );

Calls the L<localiser|Class::Usul::Cmd/l10n> with the passed options. Adds the
program leader and prints the result to I<STDOUT>

=cut

sub output {
   my ($self, $text, $opts) = @_;

   $opts //= {};
   $text = $self->_localise($text, $opts, TRUE);

   my $code = sub {
      $opts->{to} && $opts->{to} eq 'err' ? emit_err(@_) : emit(@_);
   };

   $code->() if $opts->{cl};
   $code->($self->add_leader($text, $opts));
   $code->() if $opts->{nl};
   return TRUE;
}

=item C<quiet>

   $bool = $self->quiet( $bool );

Custom accessor/mutator for the C<quiet_flag> attribute. Will throw if you try
to turn quiet mode off

=cut

sub quiet {
   my ($self, $v) = @_;

   return $self->_quiet_flag unless defined $v;

   $v = !!$v;

   throw 'Cannot turn quiet mode off' unless $v;

   return $self->_set__quiet_flag($v);
}

=item C<warning>

   $self->warning( $text, \%opts );

Calls the L<localiser|Class::Usul::Cmd/l10n> with the passed options. Logs the
result at the warning level, then adds the program leader and prints the result
to I<STDOUT>

=cut

sub warning {
   my ($self, $text, $opts) = @_;

   $opts //= {};
   $text = $self->_localise($text, $opts);

   if ($self->log) {
      $self->log->warn($self->add_leader($_, $opts))
         for (split m{ \n }mx, $text);
   }

   emit $self->add_leader($text, $opts) unless $self->quiet || $opts->{quiet};

   return TRUE;
}

# Private methods
sub _localise {
   my ($self, $text, $opts, $quote) = @_;

   $opts //= {};

   return $self->localize($text // '[no message]', {
      locale               => $self->locale,
      no_quote_bind_values => $quote // $opts->{no_quote_bind_values} // FALSE,
      params               => $opts->{args} // [],
   });
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

=item L<Text::Autoformat>

=item L<Moo::Role>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-Usul-Cmd.  Patches are welcome

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
