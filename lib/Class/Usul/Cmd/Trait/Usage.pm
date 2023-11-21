package Class::Usul::Cmd::Trait::Usage;

use attributes ();

use Class::Usul::Cmd::Constants qw( DUMP_EXCEPT FAILED FALSE NUL OK SPC TRUE );
use Class::Usul::Cmd::Types     qw( ArrayRef Bool DataEncoding Str );
use Class::Usul::Cmd::Util      qw( dash2under data_dumper emit emit_to
                                    ensure_class_loaded find_source is_member
                                    list_attr_of pad tempfile throw
                                    untaint_cmdline untaint_identifier );
use English                     qw( -no_match_vars );
use File::DataClass::IO         qw( io );
use File::DataClass::Types      qw( File );
use Scalar::Util                qw( blessed );
use Sub::Identify               qw( sub_fullname );
use Class::Inspector;
use Try::Tiny;
use Moo::Role;
use Class::Usul::Cmd::Options;

requires qw( config next_argv options_usage output quiet run_cmd );

=pod

=encoding utf-8

=head1 Name

Class::Usul::Cmd::Trait::Usage - Help and diagnostic information for command line programs

=head1 Synopsis

   use Moo;

   extends 'Class::Usul::Cmd';
   with    'Class::Usul::Cmd::Trait::Usage';

=head1 Description

Help and diagnostic information for command line programs

=head1 Configuration and Environment

Requires the following;

=over 3

=item C<config>

=item C<next_argv>

=item C<options_usage>

=item C<output>

=item C<quiet>

=item C<run_cmd>

=back

Defines the following attributes;

=over 3

=item C<app_version>

The version exported by the application class defined in the configuration

=cut

has 'app_version' =>
   is      => 'lazy',
   isa     => Str,
   default => sub {
      my $self  = shift;
      my $class = $self->config->appclass;
      my $ver   = try {
         ensure_class_loaded $class; $class->VERSION
      } catch { '?' };

      return $ver;
   },
   init_arg => undef;

=item C<encoding>

Decode/encode input/output using this encoding

=cut

option 'encoding' =>
   is            => 'lazy',
   isa           => DataEncoding,
   default       => 'UTF-8',
   documentation => 'Decode/encode input/output using this encoding',
   format        => 's';

=item C<H help_manual>

Print long help text extracted from this POD

=cut

option 'help_manual' =>
   is            => 'ro',
   isa           => Bool,
   default       => FALSE,
   documentation => 'Displays the documentation for the program',
   short         => 'H';

=item C<h help_options>

Print short help text extracted from this POD

=cut

option 'help_options' =>
   is            => 'ro',
   isa           => Bool,
   default       => FALSE,
   documentation => 'Describes program options and methods',
   short         => 'h';

=item C<? help_usage>

Print option usage

=cut

option 'help_usage' =>
   is            => 'ro',
   isa           => Bool,
   default       => FALSE,
   documentation => 'Displays this command line usage',
   short         => '?';

=item C<show_version>

Prints the programs version number and exits

=cut

option 'show_version' =>
   is            => 'ro',
   isa           => Bool,
   default       => FALSE,
   documentation => 'Displays the version number of the program class';

has '_doc_title' =>
   is      => 'lazy',
   isa     => Str,
   default => sub {
      my $self = shift;
      my $config = $self->config;

      return $config->doc_title if $config->can('doc_title');

      return $config->name if $config->can('name');

      return 'User Documentation';
   };

has '_man_page_cmd' =>
   is      => 'lazy',
   isa     => ArrayRef,
   default => sub {
      my $self = shift;

      return $self->config->man_page_cmd if $self->config->can('man_page_cmd');

      return ['nroff', '-man'];
   };

has '_pathname' =>
   is      => 'lazy',
   isa     => File,
   default => sub {
      my $name = $PROGRAM_NAME;

      $name = '-' eq substr($name, 0, 1) ? $EXECUTABLE_NAME : $name;

      return io((split m{ [ ][\-][ ] }mx, $name)[0])->absolute;
   };

has '_script' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->_pathname->basename };

=back

=head1 Subroutines/Methods

=over 3

=item C<BUILD>

Called just after the object is constructed this method handles dispatching
to the help methods

=cut

before 'BUILD' => sub {
   my $self = shift;

   $self->_apply_stdio_encoding;
   $self->exit_usage(0) if $self->help_usage;
   $self->exit_usage(1) if $self->help_options;
   $self->exit_usage(2) if $self->help_manual;
   $self->_exit_version if $self->show_version;
   return;
};

=item C<can_call>

   $bool = $self->can_call( $method );

Returns true if C<$self> has a method given by C<$method> that has defined
the I<method> method attribute

=cut

my $_can_call_cache = {};

sub can_call {
   my ($self, $wanted) = @_;

   return FALSE unless $wanted;

   unless (exists $_can_call_cache->{$wanted}) {
      $_can_call_cache->{$wanted}
         = (is_member $wanted, _list_methods_of($self)) ? TRUE : FALSE;
   }

   return $_can_call_cache->{$wanted};
}

=item C<dump_config> - Dumps the configuration attributes and values

Visits the configuration object, forcing evaluation of the lazy, and printing
out the attributes and values

=cut

sub dump_config : method {
   my $self    = shift;
   my $methods = [];
   my %seen    = ();

   for my $class (reverse @{$self->_get_classes_and_roles($self->config)}) {
      next if $class eq 'Moo::Object';
      push @{$methods},
         map  { my $k = (split m{ :: }mx, $_)[-1]; $seen{$k} = TRUE; $_ }
         grep { my $k = (split m{ :: }mx, $_)[-1]; !$seen{$k} }
         grep { $_ !~ m{ \A Moo::Object }mx }
         @{Class::Inspector->methods($class, 'full', 'public')};
   }

   $self->dumper([ list_attr_of $self->config, $methods, DUMP_EXCEPT ]);

   return OK;
}

=item C<dump_self> - Dumps the program object

Dumps out the self referential object using L<Data::Printer>

=cut

sub dump_self : method {
   my $self = shift;

   $self->dumper($self);
   $self->dumper($self->config);
   return OK;
}

=item C<dumper>

Calls L<data dumper|Class::Usul::Cmd::Trait::Util/data_dumper> on the supplied
arguments

=cut

sub dumper {
   my $self = shift; return data_dumper(@_);
}

=item C<exit_usage>

   $self->exit_usage( $level );

Prints out the usage information at the given level of verbosity

=cut

sub exit_usage {
   my ($self, $level) = @_;

   $self->quiet(TRUE);

   my $rv = $self->_output_usage($level);

   if ($level == 0) { emit "\nMethods:\n"; $self->list_methods }

   exit $rv;
}

=item C<help> - Display help text about a method

Searches the programs classes and roles to find the method implementation.
Displays help text from the POD that describes the method

=cut

sub help : method {
   my $self = shift;

   $self->_output_usage(1);
   return OK;
}

=item C<list_methods> - Lists available command line methods

Lists the methods (marked by the I<method> subroutine attribute) that can
be called via the L<run method|Class::Usul::Cmd::Trait::RunningMethods/run>

=cut

sub list_methods : method {
   my $self = shift;

   ensure_class_loaded 'Pod::Eventual::Simple';

   my $abstract = {};
   my $max = 0;
   my $classes = $self->_get_classes_and_roles;

   for my $method (@{_list_methods_of($self)}) {
      my $mlen = length $method;

      $max = $mlen if $mlen > $max;

      for my $class (@{$classes}) {
         next unless is_member $method,
            Class::Inspector->methods($class, 'public');

         my $pod = _get_pod_header_for_method($class, $method) or next;

         $abstract->{$method} = $pod if !exists $abstract->{$method}
            or length $pod > length $abstract->{$method};
      }

      $abstract->{$method} = "${method} - Failure to document"
         unless exists $abstract->{$method};
   }

   for my $key (sort keys %{$abstract}) {
      my ($method, @rest) = split SPC, $abstract->{$key};

      $key =~ s{ [_] }{-}gmx;
      emit((pad $key, $max) . SPC . (join SPC, @rest));
   }

   return OK;
}

# Private methods
sub _apply_stdio_encoding {
   my $self = shift;
   my $enc  = untaint_cmdline $self->encoding;

   for (*STDIN, *STDOUT, *STDERR) {
      next unless $_->opened;
      binmode $_, ":encoding(${enc})";
   }

   autoflush STDOUT TRUE;
   autoflush STDERR TRUE;
   return;
}

sub _exit_version {
   my $self = shift;

   $self->output('Version ' . $self->app_version);
   exit OK;
}

sub _get_classes_and_roles {
   my ($self, $target) = @_;

   $target //= $self;

   ensure_class_loaded 'mro';

   my @classes = @{ mro::get_linear_isa(blessed $target) };
   my %uniq = ();

   while (my $class = shift @classes) {
      $class = (split m{ __WITH__ }mx, $class)[0];
      next if $class =~ m{ ::_BASE \z }mx;
      $class =~ s{ \A Role::Tiny::_COMPOSABLE:: }{}mx;
      next if $uniq{$class};
      $uniq{$class}++;

      push @classes, keys %{$Role::Tiny::APPLIED_TO{$class}}
         if exists $Role::Tiny::APPLIED_TO{$class};
   }

   return [ sort keys %uniq ];
}

sub _man_page_from {
   my ($self, $src, $errors) = @_;

   ensure_class_loaded 'Pod::Man';

   my $config = $self->config;
   my $parser = Pod::Man->new(
      center  => $self->_doc_title,
      errors  => $errors // 'pod',
      name    => $self->_script,
      release => 'Version ' . $self->app_version,
      section => '3m'
   );
   my $tfile = tempfile($self);

   $parser->parse_from_file($src->pathname . NUL, $tfile->pathname);

   my $cmd = $self->_man_page_cmd || [];

   emit $self->run_cmd([ @{$cmd}, $tfile->pathname ])->out;
   return OK;
}

sub _output_usage {
   my ($self, $verbose) = @_;

   my $method = $self->next_argv;

   $method = untaint_identifier dash2under $method if defined $method;

   return $self->_usage_for($method) if $self->can_call($method);

   return $self->_man_page_from($self->_pathname) if $verbose > 1;

   ensure_class_loaded 'Pod::Usage';
   Pod::Usage::pod2usage({
      -exitval => OK,
      -input   => $self->_pathname . NUL,
      -message => SPC,
      -verbose => $verbose
   }) if $verbose > 0; # Never returns

   emit_to \*STDERR, $self->options_usage;
   return FAILED;
}

sub _usage_for {
   my ($self, $method) = @_;

   my $fullname = sub_fullname($self->can($method));

   for my $class (@{$self->_get_classes_and_roles}) {
      next unless $fullname eq "${class}::${method}";

      ensure_class_loaded 'Pod::Simple::Select';

      my $parser = Pod::Simple::Select->new;
      my $tfile  = tempfile($self);

      $parser->select(['head2|item' => [$method]]);
      $parser->output_file($tfile->pathname);
      $parser->parse_file(find_source $class);

      return $self->_man_page_from($tfile, 'none') if $tfile->stat->{size} > 0;
   }

   emit_to \*STDERR, "Method ${method} no documentation found\n";
   return FAILED;
}

# Private functions
my $_method_cache = {};

sub _list_methods_of {
   my $class = blessed $_[0] || $_[0];

   unless (exists $_method_cache->{$class}) {
      $_method_cache->{$class} = [
         map  { s{ \A .+ :: }{}msx; $_ }
         grep { my $subr = $_;
                grep { $_ eq 'method' } attributes::get(\&{$subr}) }
         @{ Class::Inspector->methods($class, 'full', 'public') }
      ];
   }

   return $_method_cache->{$class};
}

sub _get_pod_header_for_method {
   my ($class, $method) = @_;

   my $src = find_source $class
      or throw 'Class [_1] cannot find source', [$class];
   my $ev  = [
      grep { $_->{content} =~ m{ (?: ^|[< ]) $method (?: [ >]|$ ) }msx}
      grep { $_->{type} eq 'command' }
      @{ Pod::Eventual::Simple->read_file($src) }
   ];
   my $pod = $ev->[0] ? $ev->[0]->{content} : undef;

   chomp $pod if $pod;
   return $pod;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<attributes>

=item L<Class::Inspector>

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
