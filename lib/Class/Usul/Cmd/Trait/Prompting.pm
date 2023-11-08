package Class::Usul::Cmd::Trait::Prompting;

use Class::Usul::Cmd::Constants qw( BRK FAILED FALSE NO NUL QUIT SPC TRUE YES );
use Class::Usul::Cmd::Types     qw( PositiveInt );
use Class::Usul::Cmd::Util      qw( arg_list emit_to pad throw );
use English                     qw( -no_match_vars );
use Ref::Util                   qw( is_hashref );
use IO::Interactive;
use Term::ReadKey;
use Moo::Role;
use Class::Usul::Cmd::Options;

requires qw( add_leader config localize output );

=pod

=encoding utf8

=head1 Name

Class::Usul::Cmd::Trait::Prompting - Methods for requesting command line input

=head1 Synopsis

   use Moo;

   extends 'Class::Usul::Cmd';
   with    'Class::Usul::Cmd::Trait::Prompting';

=head1 Description

Methods that prompt for command line input from the user

=head1 Configuration and Environment

Defines the following options;

=over 3

=item C<pwidth>

Prompt width which defaults to sixty characters. Overridden by the configuration
if it can C<pwidth>

=cut

option 'pwidth' =>
   is            => 'rw',
   isa           => PositiveInt,
   format        => 'i',
   documentation => 'Set the prompt width this integer number',
   default       => sub {
      my $self = shift;

      return $self->config->can('pwidth') ? $self->config->pwidth : 60;
   },
   lazy          => TRUE;

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<anykey>

   $key = $self->anykey( $prompt );

Prompt string defaults to 'Press any key to continue...'. Calls and
returns L<prompt|/__prompt>. Requires the user to press any key on the
keyboard (that generates a character response)

=cut

sub anykey {
   my ($self, $prompt) = @_;

   $prompt = $self->_prepare($prompt // 'Press any key to continue');

   return _prompt(-p => "${prompt}...", -d => TRUE, -e => NUL, -1 => TRUE);
}

=item C<get_line>

   $line = $self->get_line( $question, $default, $quit, $width, $newline );

Prompts the user to enter a single line response to C<$question> which
is printed to I<STDOUT> with a program leader. If C<$quit> is true
then the options to quit is included in the prompt. If the C<$width>
argument is defined then the string is formatted to the specified
width which is C<$width> or C<< $self->pwdith >> or 40. If C<$newline>
is true a newline character is appended to the prompt so that the user
get a full line of input

=cut

sub get_line { # General text input routine.
   my ($self, $question, @args) = @_;

   my $opts = _opts('get_line', @args);

   $question = $self->_prepare($question // 'Enter your answer');

   my $default  = $opts->{default} // NUL;
   my $advice   = $opts->{quit} ? $self->_loc('([_1] to quit)', QUIT) : NUL;
   my $r_prompt = $advice . ($opts->{multiline} ? NUL : " [${default}]");
   my $l_prompt = $question;

   if (defined $opts->{width}) {
      my $total  = $opts->{width} || $self->pwidth;
      my $left_x = $total - (length $r_prompt);

      $l_prompt = sprintf '%-*s', $left_x, $question;
   }

   my $prompt  = "${l_prompt} ${r_prompt}"
               . ($opts->{multiline} ? "\n[${default}]" : NUL) . BRK;
   my $result  = $opts->{noecho}
               ? _prompt(-d => $default, -p => $prompt, -e => '*')
               : _prompt(-d => $default, -p => $prompt);

   exit FAILED if $opts->{quit} and defined $result and lc $result eq QUIT;

   return "${result}";
}

=item C<get_option>

   $option = $self->get_option( $question, $default, $quit, $width, $options );

Returns the selected option number from the list of possible options passed
in the C<$question> argument

=cut

sub get_option { # Select from an numbered list of options
   my ($self, $prompt, @args) = @_;

   my $opts = _opts('get_option', @args);

   $prompt //= '+Select one option from the following list:';

   my $no_lead = ('+' eq substr $prompt, 0, 1) ? FALSE : TRUE;
   my $leader  = $no_lead ? NUL : '+'; $prompt =~ s{ \A \+ }{}mx;
   my $max     = @{ $opts->{options} // [] };

   $self->output($prompt, { no_lead => $no_lead });

   my $count = 1;
   my $text  = join "\n", map { _justify_count($max, $count++) . " - ${_}" }
                             @{ $opts->{options} // [] };

   $self->output($text, { cl => TRUE, nl => TRUE, no_lead => $no_lead });

   my $question = "${leader}Select option";
   my $opt      = $self->get_line($question, $opts);

   $opt = $opts->{default} // 0 if $opt !~ m{ \A \d+ \z }mx;

   return $opt - 1;
}

=item C<is_interactive>

   $bool = $self->is_interactive( $optional_filehandle );

Exposes L<IO::Interactive/is_interactive>

=cut

sub is_interactive {
   my $self = shift; return IO::Interactive::is_interactive(@_);
}

=item C<yorn>

   $self->yorn( $question, $default, $quit, $width );

Prompt the user to respond to a yes or no question. The C<$question>
is printed to I<STDOUT> with a program leader. The C<$default>
argument is C<0|1>. If C<$quit> is true then the option to quit is
included in the prompt. If the C<$width> argument is defined then the
string is formatted to the specified width which is C<$width> or
C<< $self->pwdith >> or 40

=cut

sub yorn { # General yes or no input routine
   my ($self, $question, @args) = @_;

   my $opts = _opts('yorn', @args);

   $question = $self->_prepare($question // 'Choose');

   my $no       = NO;
   my $yes      = YES;
   my $default  = $opts->{default} ? $yes : $no;
   my $quit     = $opts->{quit   } ? QUIT : NUL;
   my $advice   = $quit ? "(${yes}/${no}, ${quit}) " : "(${yes}/${no}) ";
   my $r_prompt = "${advice}[${default}]";
   my $l_prompt = $question;

   if (defined $opts->{width}) {
      my $max_width = $opts->{width} || $self->pwidth;
      my $right_x   = length $r_prompt;
      my $left_x    = $max_width - $right_x;

      $l_prompt = sprintf '%-*s', $left_x, $question;
   }

   my $prompt = "${l_prompt} ${r_prompt}".BRK.($opts->{newline} ? "\n" : NUL);

   while (my $result = _prompt(-d => $default, -p => $prompt)) {
      exit FAILED if $quit and $result =~ m{ \A (?: $quit | [\e] ) }imx;
      return TRUE if $result =~ m{ \A $yes }imx;
      return FALSE if $result =~ m{ \A $no  }imx;
   }

   return;
}

# Private methods
sub _loc {
   my ($self, $text, @args) = @_;

   return $self->localize($text // '[no message]', {
      locale               => $self->locale,
      no_quote_bind_values => TRUE,
      params               => [@args],
   });
}

sub _prepare {
   my ($self, $question) = @_;

   my $add_leader;

   if ('+' eq substr $question, 0, 1) {
      $question = substr $question, 1;
      $add_leader = TRUE;
   }

   $question = $self->_loc($question);
   $question = $self->add_leader($question) if $add_leader;
   return $question;
}

# Private functions
sub _default_input {
   my ($fh, $args) = @_;

   return $args->{default}
      if $ENV{PERL_MM_USE_DEFAULT} or $ENV{PERL_MB_USE_DEFAULT};
   return getc $fh if $args->{onechar};
   return scalar <$fh>;
}

sub _get_control_chars {
   # Returns a string of pipe separated control
   # characters and a hash of symbolic names and values
   my $handle = shift;
   my %cntl   = GetControlChars $handle;

   return ((join '|', values %cntl), %cntl);
}

sub _justify_count {
   return pad $_[1], int log $_[0] / log 10, SPC, 'left';
}

sub _map_prompt_args { # IO::Prompt equiv. sub has an obscure bug so this
   my $args = shift;
   my %map  = ( qw(-1 onechar -d default -e echo -p prompt) );

   for (grep { exists $map{$_} } keys %{ $args }) {
      $args->{ $map{$_} } = delete $args->{$_};
   }

   return $args;
}

sub _opts {
   my ($type, @args) = @_;

   return $args[0] if is_hashref $args[0];

   my $attr = { default => $args[0], quit => $args[1], width => $args[2]};

   if ($type eq 'get_line') {
      $attr->{multiline} = $args[3];
      $attr->{noecho} = $args[4];
   }
   elsif ($type eq 'get_option') { $attr->{options} = $args[3] }
   elsif ($type eq 'yorn')       { $attr->{newline} = $args[3] }

   return $attr;
}

sub _raw_mode { # Puts the terminal in raw input mode
   my $handle = shift; ReadMode 'raw', $handle; return;
}

sub _restore_mode { # Restores line input mode to the terminal
   my $handle = shift; ReadMode 'restore', $handle; return;
}

sub _prompt {
   # This was taken from L<IO::Prompt> which has an obscure bug in it
   my $args    = _map_prompt_args(arg_list @_);
   my $default = $args->{default};
   my $echo    = $args->{echo   };
   my $onechar = $args->{onechar};
   my $OUT     = \*STDOUT;
   my $IN      = \*STDIN;
   my $input   = NUL;

   return _default_input($IN, $args) unless IO::Interactive::is_interactive();

   my ($len, $newlines, $next, $text);
   my ($cntl, %cntl) = _get_control_chars($IN);
   local $SIG{INT}   = sub { _restore_mode($IN); exit FAILED };

   emit_to $OUT, $args->{prompt};
   _raw_mode($IN);

   while (TRUE) {
      if (defined ($next = getc $IN)) {
         if ($next eq $cntl{INTERRUPT}) {
            _restore_mode($IN);
            exit FAILED;
         }
         elsif ($next eq $cntl{ERASE}) {
            if ($len = length $input) {
               $input = substr $input, 0, $len - 1;
               emit_to $OUT, "\b \b";
            }

            next;
         }
         elsif ($next eq $cntl{EOF}) {
            _restore_mode($IN);
            throw 'IO error: [_1]', [ $OS_ERROR ] unless close $IN;
            return $input;
         }
         elsif ($next !~ m{ $cntl }mx) {
            $input .= $next;

            if ($next eq "\n") {
               if ($input eq "\n" and defined $default) {
                  $text = defined $echo ? $echo x length $default : $default;
                  emit_to $OUT, "[${text}]\n";
                  _restore_mode($IN);

                  return $onechar ? substr $default, 0, 1 : $default;
               }

               $newlines .= "\n";
            }
            else { emit_to $OUT, $echo // $next }
         }
         else { $input .= $next }
      }

      if ($onechar or not defined $next or $input =~ m{ \Q$RS\E \z }mx) {
         chomp $input;
         _restore_mode($IN);
         emit_to $OUT, $newlines if defined $newlines;
         return $onechar ? substr $input, 0, 1 : $input;
      }
   }

   return;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<IO::Interactive>

=item L<Term::ReadKey>

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
