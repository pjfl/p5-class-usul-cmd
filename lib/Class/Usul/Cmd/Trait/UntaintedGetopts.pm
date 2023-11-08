package Class::Usul::Cmd::Trait::UntaintedGetopts;

use Class::Usul::Cmd::Constants qw( FAILED NUL QUOTED_RE TRUE );
use Class::Usul::Cmd::Getopt    qw( describe_options );
use Class::Usul::Cmd::Types     qw( ArrayRef );
use Class::Usul::Cmd::Util      qw( emit_err untaint_cmdline );
use Encode                      qw( decode );
use JSON::MaybeXS               qw( decode_json );
use Scalar::Util                qw( blessed );
use Data::Record;
use Moo::Role;

my $Extra_Argv = [];
my $Untainted_Argv = [];
my $Usage = "Did we forget new_with_options?\n";

has '_extra_argv' =>
   is      => 'lazy',
   isa     => ArrayRef,
   default => sub { [@{$Extra_Argv}] };

has '_untainted_argv' =>
   is      => 'lazy',
   isa     => ArrayRef,
   default => sub { [@{$Untainted_Argv}] };

# Construction
sub new_with_options {
   my $self = shift; return $self->new($self->_parse_options(@_));
}

# Public methods
sub extra_argv {
   return defined $_[1] ? $_[0]->_extra_argv->[$_[1]] : $_[0]->_extra_argv;
}

sub next_argv {
   return shift @{$_[0]->_extra_argv};
}

sub options_usage {
   return ucfirst $Usage;
}

sub unshift_argv {
   return unshift @{$_[0]->_extra_argv}, $_[1];
}

sub untainted_argv {
   return defined $_[1] ? $_[0]->_untainted_argv->[$_[1]]
                        : $_[0]->_untainted_argv;
}

# Private methods
sub _parse_options {
   my ($self, %args) = @_;

   my $class  = blessed $self || $self;
   my %data   = $class->_options_data;
   my %config = $class->_options_config;
   my $enc    = $config{encoding} // 'UTF-8';
   my @skip_options;

   @skip_options = @{$config{skip_options}} if defined $config{skip_options};

   delete @data{@skip_options} if @skip_options;

   my ($splitters, @options) = _build_options(\%data);
   my @gld_attr = ('getopt_conf', 'show_defaults');
   my $usage_opt = $config{usage_opt} ? $config{usage_opt} : 'Usage: %c %o';
   my (%gld_conf, $opt);

   @gld_conf{@gld_attr} = @config{@gld_attr};
   _set_usage_conf($config{usage_conf}) if $config{usage_conf};
   local @ARGV = @ARGV if $config{protect_argv};
   @ARGV = map { decode($enc, $_) } @ARGV if $enc;
   @ARGV = map { untaint_cmdline $_ } @ARGV unless $config{no_untaint};
   $Untainted_Argv = [@ARGV];
   @ARGV = _split_args($splitters) if keys %{$splitters};
   ($opt, $Usage) = describe_options($usage_opt, @options, \%gld_conf);
   $Extra_Argv = [@ARGV];

   my ($params, @missing) = _extract_params(\%args, \%config, \%data, $opt);

   if ($config{missing_fatal} && @missing) {
      emit_err join("\n", map { "Option '${_}' is missing" } @missing);
      emit_err $Usage;
      exit FAILED;
   }

   return %{$params};
}

# Private functions
sub _build_options {
   my $options_data = shift;
   my $splitters = {};
   my @options = ();

   for my $name (sort  { _sort_options($options_data, $a, $b) }
                 keys %{$options_data}) {
      my $option = $options_data->{$name};
      my $cfg    = $option->{config} // {};
      my $doc    = $option->{doc} // "No help for ${name}";

      push @options, [ _option_specification($name, $option), $doc, $cfg ];
      next unless defined $option->{autosplit};
      $splitters->{$name} = Data::Record->new({
         split => $option->{autosplit}, unless => QUOTED_RE
      });
      $splitters->{$option->{short}} = $splitters->{$name} if $option->{short};
   }

   return ($splitters, @options);
}

sub _extract_params {
   my ($args, $config, $options_data, $cmdline_opt) = @_;

   my $params = { %{$args} };
   my $prefer = $config->{prefer_commandline};
   my @missing_required;

   for my $name (keys %{$options_data}) {
      my $option = $options_data->{$name};

      if ($prefer || !defined $params->{$name}) {
         my $val = $cmdline_opt->$name();

         $params->{$name} = $option->{json} ? decode_json($val) : $val
            if defined $val;
      }

      push @missing_required, $name
         if $option->{required} && !defined $params->{$name};
   }

   return ($params, @missing_required);
}

sub _option_specification {
   my ($name, $opt) = @_;

   my $dash_name   = $name; $dash_name =~ tr/_/-/; # Dash name support
   my $option_spec = $dash_name;

   $option_spec .= '|' . $opt->{short} if defined $opt->{short};
   $option_spec .= '+' if $opt->{repeatable} && !defined $opt->{format};
   $option_spec .= '!' if $opt->{negateable};
   $option_spec .= '=' . $opt->{format} if defined $opt->{format};

   return $option_spec;
}

sub _set_usage_conf { # Should be in describe_options third argument
   return Class::Usul::Cmd::Getopt::Usage->usage_conf($_[0]);
}

sub _split_args {
   my $splitters = shift;

   my @new_argv;

   for (my $i = 0, my $nargvs = @ARGV; $i < $nargvs; $i++) { # Parse all argv
      my $arg = $ARGV[$i];

      my ($name, $value) = split m{ [=] }mx, $arg, 2; $name =~ s{ \A --? }{}mx;

      if (my $splitter = $splitters->{$name}) {
         $value //= $ARGV[++$i];

         for my $subval (map { s{ \A [\'\"] | [\'\"] \z }{}gmx; $_ }
                         $splitter->records($value)) {
            push @new_argv, "--${name}", $subval;
         }
      }
      else { push @new_argv, $arg }
   }

   return @new_argv;
}

sub _sort_options {
   my ($opts, $a, $b) = @_;

   my $max = 999;
   my $oa  = $opts->{$a}{order} || $max;
   my $ob  = $opts->{$b}{order} || $max;

   return ($oa == $max) && ($ob == $max) ? $a cmp $b : $oa <=> $ob;
}

use namespace::autoclean;

1;

__END__

=pod

=head1 Name

Class::Usul::TraitFor::UntaintedGetopts - Untaints @ARGV before Getopts processes it

=head1 Synopsis

   use Moo;

   with 'Class::Usul::TraitFor::UntaintedGetopts';

=head1 Description

Untaints C<@ARGV> before Getopts processes it. Replaces L<MooX::Options>
with an implementation closer to L<MooseX::Getopt::Dashes>

=head1 Configuration and Environment

Modifies C<new_with_options> and C<options_usage>

=head1 Subroutines/Methods

=head2 extra_argv

Returns an array ref containing the remaining command line arguments

=head2 new_with_options

Parses the command line options and then calls the constructor

=head2 next_argv

Returns the next value from L</extra_argv> shifting the value off the list

=head2 options_usage

Returns the options usage string

=head2 _parse_options

Untaints the values of the C<@ARGV> array before the are parsed by
L<Getopt::Long::Descriptive>

=head2 unshift_argv

Pushes the supplied argument back onto the C<extra_argv> list

=head2 untainted_argv

Returns all of the arguments passed, untainted, before L<Getopt::Long> parses
them

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Data::Record>

=item L<Encode>

=item L<Getopt::Long>

=item L<Getopt::Long::Descriptive>

=item L<JSON::MaybeXS>

=item L<Moo::Role>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2018 Peter Flanigan. All rights reserved

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
