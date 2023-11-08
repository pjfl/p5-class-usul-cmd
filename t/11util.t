use t::boilerplate;

use Test::More;

use Capture::Tiny          qw( capture );
use English                qw( -no_match_vars );
use File::Spec::Functions  qw( catdir catfile updir );
use Class::Usul::Cmd::Util qw( :all );

is abs_path(catfile('t', updir, 't')), File::Spec->rel2abs('t'), 'abs_path';

is app_prefix( 'Test::Application' ), 'test_application', 'app_prefix';
is app_prefix( undef ), q(), 'app_prefix - undef arg';

my $list = arg_list( 'key1' => 'value1', 'key2' => 'value2' );

is $list->{key2}, 'value2', 'arg_list';

is classfile('Test::App'), catfile(qw( Test App.pm )), 'classfile';

is dash2under('foo-bar'), 'foo_bar', 'dash2under';

ok defined elapsed, 'elapsed';

my ($stdout, $stderr, $exit) = capture { emit 'test'; }; chomp $stdout;

is $stdout, 'test', 'emit';

($stdout, $stderr, $exit) = capture { emit_err 'test'; }; chomp $stderr;

is $stderr, 'test', 'emit_err';

eval {
   ensure_class_loaded( 'Class::Usul::Cmd::IPC::Response' );
   Class::Usul::Cmd::IPC::Response->new;
};

ok !exception, 'ensure_class_loaded';

is env_prefix( 'Test::Application' ), 'TEST_APPLICATION', 'env_prefix';

my $path = find_source( 'Class::Usul::Cmd::Util' );

is $path, abs_path(catfile(qw( lib Class Usul Cmd Util.pm ))), 'find_source';

ok is_member( 2, 1, 2, 3 ),  'is_member - true';
ok !is_member( 4, 1, 2, 3 ), 'is_member - false';

ok defined loginid(), 'loginid';
ok defined logname(), 'logname';

my $src = { 'key2' => 'value2', }; my $dest = {};

merge_attributes $dest, $src, { 'key1' => 'value3', }, [ 'key1', 'key2', ];

is $dest->{key1}, q(value3), 'merge_attributes - default';
is $dest->{key2}, q(value2), 'merge_attributes - source';

is pad( 'x', 7, q( ), 'both'  ), '   x   ', 'pad - both';
is pad( 'x', 7, q( ), 'left'  ), '      x', 'pad - left';
is pad( 'x', 7, q( ), 'right' ), 'x      ', 'pad - right';

is squeeze( q(a  b  c) ), q(a b c), 'squeeze';

is strip_leader( q(test: dummy) ), q(dummy), 'strip_leader';

eval { throw( error => q(eNoMessage) ) };

my $e = exception; $EVAL_ERROR = undef;

like $e->as_string, qr{ eNoMessage }msx, 'try/throw/catch exception';

is time2str(undef, 0, 'UTC'), '1970-01-01 00:00:00', 'time2str';

is trim( q(  test string  ) ), q(test string), 'trim - spaces';

is trim( q(/test string/), q(/) ), q(test string), 'trim - other chars';

eval { untaint_cmdline( '&&&' ) }; $e = exception; $EVAL_ERROR = undef;

is $e->class, q(Tainted), 'untaint_cmdline';

eval { untaint_identifier( 'no-chance' ) }; $e = exception; $EVAL_ERROR = undef;

is $e->class, q(Tainted), 'untaint_identifier';

eval { untaint_path( '$$$' ) }; $e = exception; $EVAL_ERROR = undef;

is $e->class, q(Tainted), 'untaint_path';

eval { untaint_path( 'x$x' ) }; $e = exception; $EVAL_ERROR = undef;

is $e->class, q(Tainted), 'untaint_path - 2';

done_testing;
