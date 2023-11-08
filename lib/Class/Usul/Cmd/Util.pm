package Class::Usul::Cmd::Util;

use strictures;
use parent 'Exporter::Tiny';

use Class::Null;
use Class::Usul::Cmd::Constants qw( EXCEPTION_CLASS FALSE SPC NUL TRUE
                                    UNTAINT_CMDLINE UNTAINT_IDENTIFIER
                                    UNTAINT_PATH );
use Cwd                         qw( );
use Date::Format                  ( );
use English                     qw( -no_match_vars );
use Fcntl                       qw( F_SETFL O_NONBLOCK );
use File::DataClass::IO         qw( io );
use File::Spec::Functions       qw( catfile tmpdir );
use List::Util                  qw( first );
use Module::Runtime             qw( is_module_name require_module );
use Ref::Util                   qw( is_arrayref is_hashref );
use Scalar::Util                qw( blessed openhandle );
use Time::HiRes                 qw( usleep );
use Unexpected::Functions       qw( is_class_loaded Tainted Unspecified );
use User::pwent;

use Data::Printer alias => '_data_dumper', colored => TRUE, indent => 3,
   filters => [{
      'DateTime'            => sub { $_[0] . NUL         },
      'File::DataClass::IO' => sub { $_[0]->pathname     },
      'JSON::XS::Boolean'   => sub { $_[0] . NUL         },
      'Type::Tiny'          => sub { $_[0]->display_name },
      'Type::Tiny::Enum'    => sub { $_[0]->display_name },
      'Type::Tiny::Union'   => sub { $_[0]->display_name },
   }];

our @EXPORT_OK = qw( abs_path app_prefix arg_list classfile dash2under
   data_dumper delete_tmp_files elapsed emit emit_err emit_to
   ensure_class_loaded env_prefix exception find_source get_user is_member
   is_win32 list_attr_of loginid logname merge_attributes nap
   nonblocking_write_pipe_pair ns_environment pad squeeze strip_leader tempdir
   tempfile throw time2str trim untaint_cmdline untaint_identifier untaint_path
   );

our %EXPORT_TAGS = (all => [@EXPORT_OK]);

=pod

=head1 Name

Class::Usul::Cmd::Util - Importable utility functions

=head1 Synopsis

   package MyBaseClass;

   use Class::Usul::Cmd::Util qw( functions to import );

=head1 Description

Provides importable utility functions

=head1 Subroutines/Methods

=over 3

=item C<abs_path>

   $absolute_untainted_path = abs_path $some_path;

Untaints path. Makes it an absolute path and returns it. Returns undef
otherwise. Traverses the filesystem

=cut

sub abs_path ($) {
   my $v = shift;

   return $v unless defined $v and length $v;

   return untaint_path($v) if is_ntfs() and not -e $v; # Hate

   $v = Cwd::abs_path(untaint_path($v));

   $v =~ s{ / }{\\}gmx if is_win32() and defined $v; # More hate

   return $v;
}

=item C<app_prefix>

   $prefix = app_prefix $classname;

Takes a class name and returns it lower cased with B<::> changed to
B<_>, e.g. C<App::Munchies> becomes C<app_munchies>

=cut

sub app_prefix ($) {
   (my $v = lc ($_[0] // NUL)) =~ s{ :: }{_}gmx;

   return $v;
}

=item C<arg_list>

   $args = arg_list @rest;

Returns a hash reference containing the passed parameter list. Enables
methods to be called with either a list or a hash reference as it's input
parameters

=cut

sub arg_list (;@) {
   return $_[0] && is_hashref $_[0] ? { %{$_[0]} }
        : $_[0]                     ? { @_ }
                                    : {};
}

=item C<classfile>

   $file_path = classfile $classname;

Returns the path (file name plus extension) of a given class. Uses
L<File::Spec> for portability, e.g. C<App::Munchies> becomes
C<App/Munchies.pm>

=cut

sub classfile ($) {
   return catfile(split m{ :: }mx, $_[0].'.pm');
}

=item C<dash2under>

   $string_with_underscores = dash2under 'a-string-with-dashes';

Substitutes underscores for dashes

=cut

sub dash2under (;$) {
   (my $v = $_[0] // NUL) =~ s{ [\-] }{_}gmx;

   return $v;
}

=item C<data_dumper>

   data_dumper $thing;

Uses L<Data::Printer> to dump C<$thing> in colour to I<stderr>. Returns true

=cut

sub data_dumper (;@) {
   _data_dumper(@_);
   return TRUE;
}

=item C<delete_tmp_files>

   delete_tmp_files [$object], [$dir];

Delete this processes temporary files. Files are in the C<$dir> directory
which defaults to L</tempdir>

=cut

sub delete_tmp_files (;$$){
   return io( $_[1] // tempdir($_[0]) )->delete_tmp_files;
}

=item C<elapsed>

   $elapsed_seconds = elapsed;

Returns the number of seconds elapsed since the process started

=cut

sub elapsed () {
   return time - $BASETIME;
}

=item C<emit>

   emit @lines_of_text;

Prints to I<STDOUT> the lines of text passed to it. Lines are C<chomp>ed
and then have newlines appended. Throws on IO errors

=cut

sub emit (;@) {
   my @args = @_;

   $args[0] //= NUL;
   chomp(@args);
   local ($OFS, $ORS) = ("\n", "\n");

   return openhandle *STDOUT ? emit_to(*STDOUT, @args) : undef;
}

=item C<emit_err>

   emit_err @lines_of_text;

Like L</emit> but output to C<STDERR>

=cut

sub emit_err (;@) {
   my @args = @_;

   $args[0] //= NUL;
   chomp(@args);
   local ($OFS, $ORS) = ("\n", "\n");

   return openhandle *STDERR ? emit_to(*STDERR, @args) : undef;
}

=item C<emit_to>

   emit_to $filehandle, @lines_of_text;

Prints to the specified file handle

=cut

sub emit_to ($;@) {
   my ($handle, @args) = @_;

   local $OS_ERROR;

   return (print {$handle} @args or throw('IO error: [_1]', [$OS_ERROR]));
}

=item C<ensure_class_loaded>

   ensure_class_loaded $some_class, $options_ref;

Require the requested class, throw an error if it doesn't load

=cut

sub ensure_class_loaded ($;$) {
   my ($class, $opts) = @_;

   throw(Unspecified, ['class name'], level => 2) unless $class;

   throw('String [_1] invalid classname', [$class], level => 2)
      unless is_module_name($class);

   $opts //= {};
   return TRUE if !$opts->{ignore_loaded} && is_class_loaded($class);

   eval { require_module($class) }; throw_on_error({ level => 3 });

   throw('Class [_1] loaded but package undefined', [$class], level => 2)
      unless is_class_loaded($class);

   return TRUE;
}

=item C<env_prefix>

   $prefix = env_prefix $class;

Returns upper cased C<app_prefix>. Suitable as prefix for environment
variables

=cut

sub env_prefix ($) {
   return uc app_prefix($_[0]);
}

=item C<exception>

   $e = exception $error;

Expose the C<catch> method in the exception
class L<Class::Usul::Cmd::Exception>. Returns a new error object

=cut

sub exception (;@) {
   return EXCEPTION_CLASS->caught(@_);
}

=item C<find_source>

   $path = find_source $module_name;

Returns absolute path to the source code for the given module

=cut

sub find_source ($) {
   my $class = shift;
   my $file  = classfile($class);

   for (@INC) {
      my $path = abs_path(catfile($_, $file)) or next;

      return $path if -f $path;
   }

   return $INC{$file} if exists $INC{$file};

   return;
}

=item C<get_user>

   $user_object = get_user $optional_uid_or_name;

Returns the user object from a call to either C<getpwuid> or C<getpwnam>
depending on whether an integer or a string was passed. The L<User::pwent>
package is loaded so objects are returned. On MSWin32 systems returns an
instance of L<Class::Null>.  Defaults to the current uid but will lookup the
supplied uid if provided

=cut

sub get_user (;$) {
   my $user = shift;

   return Class::Null->new if is_win32();

   return getpwnam($user) if defined $user and $user !~ m{ \A \d+ \z }mx;

   return getpwuid($user // $UID);
}

=item C<is_member>

   $bool = is_member 'test_value', qw( a_value test_value b_value );

Tests to see if the first parameter is present in the list of
remaining parameters

=cut

sub is_member (;@) {
   my ($candidate, @args) = @_;

   return unless $candidate;

   @args = @{$args[0]} if is_arrayref $args[0];

   return (first { $_ eq $candidate } @args) ? TRUE : FALSE;
}

=item C<is_ntfs>

   $bool = is_ntfs;

Returns true if L</is_win32> is true or the C<$OSNAME> is C<cygwin>

=cut

sub is_ntfs () {
   return is_win32() || lc $OSNAME eq 'cygwin' ? TRUE : FALSE;
}

=item C<is_win32>

   $bool = is_win32;

Returns true if the C<$OSNAME> is C<mswin32>

=cut

sub is_win32 () {
   return lc $OSNAME eq 'mswin32' ? TRUE : FALSE;
}

=item C<list_attr_of>

   $attribute_list = list_attr_of $object_ref, @exception_list;

Lists the attributes of the object reference, including defining class name,
documentation, and current value

=cut

sub list_attr_of ($;@) {
   my ($obj, $methods, @except) = @_;

   ensure_class_loaded('Pod::Eventual::Simple');

   push @except, 'new' unless is_member 'new', @except;

   return map  { my $attr = $_->[0]; [ @{$_}, $obj->$attr ] }
          map  { [ $_->[1], $_->[0], _get_pod_content_for_attr(@{$_}) ] }
          grep { $_->[0] ne 'Moo::Object' and not is_member $_->[1], @except }
          map  { m{ \A (.+) \:\: ([^:]+) \z }mx; [$1, $2] }
              @{ $methods };
}

=item C<loginid>

   $loginid = loginid;

Returns the untainted name attribute of the object returned by a call
to L</get_user> or 'unknown' if the name attribute value is false

=cut

sub loginid (;$) {
   return untaint_cmdline(get_user($_[0])->name || 'unknown');
}

=item C<logname>

   $logname = logname;

Deprecated. Returns untainted the first true value returned by; the environment
variable C<USER>, the environment variable C<LOGNAME>, and the function
L</loginid>

=cut

sub logname (;$) { # Deprecated use loginid
   return untaint_cmdline($ENV{USER} || $ENV{LOGNAME} || loginid($_[0]));
}

=item C<merge_attributes>

   $dest = merge_attributes $dest, $src, $defaults, $attr_list_ref;

Merges attribute hashes. The C<$dest> hash is updated and returned. The
C<$dest> hash values take precedence over the C<$src> hash values which
take precedence over the C<$defaults> hash values. The C<$src> hash
may be an object in which case its accessor methods are called

=cut

sub merge_attributes ($@) {
   my ($dest, @args) = @_;

   my $attr = is_arrayref $args[-1] ? pop @args : [];

   for my $k (grep { not exists $dest->{$_} or not defined $dest->{$_} }
                  @{ $attr }) {
      my $i = 0;
      my $v;

      while (not defined $v and defined( my $src = $args[$i++] )) {
         my $class = blessed $src;

         $v = $class ? ($src->can($k) ? $src->$k() : undef) : $src->{$k};
      }

      $dest->{$k} = $v if defined $v;
   }

   return $dest;
}

=item C<nap>

   nap $period;

Sleep for a given number of seconds. The sleep time can be a fraction
of a second

=cut

sub nap ($) {
   my $period = shift;

   $period = $period && $period =~ m{ \A [\d._]+ \z }msx && $period > 0
           ? $period : 1;

   return usleep(1_000_000 * $period);
}

=item C<nonblocking_write_pipe_pair>

   $array_ref = nonblocking_write_pipe;

Returns a pair of file handles, read then write. The write file handle is
non blocking, binmode is set on both

=cut

sub nonblocking_write_pipe_pair () {
   my ($r, $w);

   throw('No pipe') unless pipe $r, $w;

   fcntl $w, F_SETFL, O_NONBLOCK;

   $w->autoflush(1);
   binmode $r;
   binmode $w;

   return [$r, $w];
}

=item C<ns_environment>

   $value = ns_environment $class, $key, [$value];

An accessor/mutator for the environment variables prefixed by the supplied
class name. Providing a value is optional, always returns the current value

=cut

sub ns_environment ($$;$) {
   my ($class, $k, $v) = @_;

   $k = (env_prefix $class) . '_' . (uc $k);

   return defined $v ? $ENV{$k} = $v : $ENV{$k};
}

=item C<pad>

   $padded_str = pad $unpadded_str, $wanted_length, $pad_char, $direction;

Pad a string out to the wanted length with the C<$pad_char> which
defaults to a space. Direction can be; I<both>, I<left>, or I<right>
and defaults to I<right>

=cut

sub pad ($$;$$) {
   my ($v, $wanted, $str, $direction) = @_;

   my $len = $wanted - length $v;

   return $v unless $len > 0;

   $str = SPC unless defined $str and length $str;

   my $pad = substr($str x $len, 0, $len);

   return $v . $pad if not $direction or $direction eq 'right';

   return $pad . $v if $direction eq 'left';

   return (substr $pad, 0, int((length $pad) / 2)) . $v
        . (substr $pad, 0, int(0.99999999 + (length $pad) / 2));
}

=item C<squeeze>

   $string = squeeze $string_containing_muliple_spaces;

Squeezes multiple whitespace down to a single space

=cut

sub squeeze (;$) {
   (my $v = $_[0] // NUL) =~ s{ \s+ }{ }gmx;

   return $v;
}

=item C<strip_leader>

   $stripped = strip_leader 'my_program: Error message';

Strips the leading "program_name: whitespace" from the passed argument

=cut

sub strip_leader (;$) {
   (my $v = $_[0] // q()) =~ s{ \A [^:]+ [:] \s+ }{}msx;

   return $v;
}

=item C<tempdir>

   $temporary_directory = tempdir [$object];

Returns C<< $object->config->tempdir >> or L<File::Spec/tmpdir> if there is no
C<$object> or it cannot C<config>, or C<config> cannot C<tempdir>

=cut

sub tempdir(;$) {
   my $config = $_[0]->config if $_[0] && $_[0]->can('config');

   return $config && $config->can('tempdir') ? $config->tempdir : tmpdir;
}

=item C<tempfile>

   $tempfile_obj = tempfile [$object], [$dir];

Returns a L<File::Temp> object in the C<$dir> directory which defaults to
L</tempdir>. File is automatically deleted if the C<$tempfile_obj> reference
goes out of scope

=cut

sub tempfile (;$$) {
   return io( $_[1] // tempdir($_[0]) )->tempfile;
}

=item C<throw>

   throw 'error_message', [ 'error_arg' ];

Expose L<Class::Usul::Cmd::Exception/throw>. L<Class::Usul::Cmd::Constants> has
a class attribute I<Exception_Class> which can be set change the class of the
thrown exception

=cut

sub throw (;@) {
   EXCEPTION_CLASS->throw(@_);
}

=item C<throw_on_error>

   throw_on_error @args;

Passes it's optional arguments to L</exception> and if an exception object is
returned it throws it. Returns undefined otherwise. If no arguments are
passed L</exception> will use the value of the global C<$EVAL_ERROR>

=cut

sub throw_on_error (;@) {
   EXCEPTION_CLASS->throw_on_error(@_);
}

=item C<time2str>

   $time_string = time2str [$format], [$time], [$zone];

Returns a formatted string representation of the given time (supplied
in seconds elapsed since the epoch). Defaults to ISO format (%Y-%m-%d
%H:%M:%S) and current time if not supplied. The timezone defaults to
local time

=cut

sub time2str (;$$$) {
   my ($format, $time, $zone) = @_;

   $format //= '%Y-%m-%d %H:%M:%S';
   $time //= time;

   return Date::Format::Generic->time2str($format, $time, $zone);
}

=item C<trim>

   $trimmed_string = trim $string_with_leading_and_trailing_whitespace;

Remove leading and trailing whitespace including trailing newlines. Takes
an additional string used as the character class to remove. Defaults to
space and tab

=cut

sub trim (;$$) {
   my $chs = $_[1] // " \t";
   (my $v = $_[0] // NUL) =~ s{ \A [$chs]+ }{}mx;

   chomp $v;
   $v =~ s{ [$chs]+ \z }{}mx;
   return $v;
}

=item C<untaint_cmdline>

   $untainted_cmdline = untaint_cmdline $maybe_tainted_cmdline;

Returns an untainted command line string. Calls L</untaint_string> with the
matching regex from L<Class::Usul::Cmd::Constants>

=cut

sub untaint_cmdline (;$) {
   return untaint_string( UNTAINT_CMDLINE, $_[0] );
}

=item C<untaint_identifier>

   $untainted_identifier = untaint_identifier $maybe_tainted_identifier;

Returns an untainted identifier string. Calls L</untaint_string> with the
matching regex from L<Class::Usul::Cmd::Constants>

=cut

sub untaint_identifier (;$) {
   return untaint_string( UNTAINT_IDENTIFIER, $_[0] );
}

=item C<untaint_path>

   $untainted_path = untaint_path $maybe_tainted_path;

Returns an untainted file path. Calls L</untaint_string> with the
matching regex from L<Class::Usul::Cmd::Constants>

=cut

sub untaint_path (;$) {
   return untaint_string( UNTAINT_PATH, $_[0] );
}

=item C<untaint_string>

   $untainted_string = untaint_string $regex, $maybe_tainted_string;

Returns an untainted string or throws

=cut

sub untaint_string ($;$) {
   my ($regex, $string) = @_;

   return unless defined $string;
   return NUL unless length $string;

   my ($untainted) = $string =~ $regex;

   throw(Tainted, [$string], level => 3)
      unless defined $untainted and $untainted eq $string;

   return $untainted;
}

# Private functions
sub _catpath {
   return untaint_path(catfile(@_));
}

sub _get_pod_content_for_attr {
   my ($class, $attr) = @_;

   my $src = find_source($class)
      or throw('Class [_1] cannot find source', [$class]);
   my $events = Pod::Eventual::Simple->read_file($src);
   my $pod;

   for (my $ev_no = 0, my $max = @{$events}; $ev_no < $max; $ev_no++) {
      my $ev = $events->[$ev_no];

      next unless $ev->{type} eq 'command';

      next unless $ev->{content} =~ m{ (?: ^|[< ]) $attr (?: [ >]|$ ) }msx;

      $ev_no++ while ($ev = $events->[$ev_no + 1] and $ev->{type} eq 'blank');

      if ($ev and $ev->{type} eq 'text') {
         $pod = $ev->{content};
         last;
      }
   }

   $pod //= 'Undocumented';
   chomp $pod;
   $pod =~ s{ [\n] }{ }gmx;
   $pod = squeeze($pod);
   $pod = $1 if $pod =~ m{ \A (.+) \z }msx;
   return $pod;
}

1;

__END__

=back

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Cmd::Constants>

=item L<Class::Usul::Cmd::Exception>

=item L<Data::Printer>

=item L<List::Util>

=back

=head1 Incompatibilities

None

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

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
