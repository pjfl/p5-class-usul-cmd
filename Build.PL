use strict;
use warnings;

use Module::Build 0.4004;

my $perl_ver = 5.010001;
my $name     = 'Class-Usul-Cmd'; $name =~ s{ - }{::}gmx;
my $prereqs  = {
  'build_requires' => {
    'Module::Build' => '0.4004',
    'version' => '0.88'
  },
  'configure_requires' => {
    'Module::Build' => '0.4004',
    'version' => '0.88'
  },
  'requires' => {
    'Class::Inspector' => '1.36',
    'Class::Null' => '2.110730',
    'Data::Printer' => '1.001000',
    'Data::Record' => '0.02',
    'Exporter::Tiny' => '1.006000',
    'File::DataClass' => 'v0.73.5',
    'Getopt::Long::Descriptive' => '0.111',
    'IO::Interactive' => '1.023',
    'JSON::MaybeXS' => '1.004004',
    'Module::Runtime' => '0.016',
    'Moo' => '2.005005',
    'Pod::Eventual' => '0.094001',
    'Ref::Util' => '0.204',
    'Sub::Identify' => '0.14',
    'Sub::Install' => '0.929',
    'Term::ReadKey' => '2.38',
    'Text::Autoformat' => '1.75',
    'TimeDate' => '1.21',
    'Try::Tiny' => '0.31',
    'Type::Tiny' => '2.002001',
    'Unexpected' => 'v1.0.6',
    'namespace::autoclean' => '0.29',
    'namespace::clean' => '0.27',
    'perl' => '5.010001',
    'strictures' => '2.000006'
  },
  'test_requires' => {
    'Capture::Tiny' => '0.22',
    'File::Spec' => '0',
    'Module::Build' => '0.4004',
    'Module::Metadata' => '0',
    'Sys::Hostname' => '0',
    'Test::Requires' => '0.06',
    'version' => '0.88'
  },
};
my $testing  = sub { $ENV{AUTOMATED_TESTING}
                  || $ENV{PERL_CPAN_REPORTER_CONFIG}
                  || $ENV{PERL5_CPANPLUS_IS_VERSION} };
my $whimper  = sub { print {*STDOUT} $_[ 0 ]."\n"; exit 0 };
my $stop     = sub {
   $testing->() or $whimper->( $_[ 0 ] );
   $prereqs->{build_requires} = { %{ $prereqs->{configure_requires} } };
   $prereqs->{test_requires } = { %{ $prereqs->{configure_requires} } };
   $prereqs->{test_requires }->{ 'Test::Requires' } = 0.06;
   delete $prereqs->{requires};
};

# Not interested in reports below min perl ver
$] < $perl_ver and $stop->( "Minimum required Perl version is ${perl_ver}" );

Module::Build->subclass( code => do { local $/; <DATA> } )->new(
   'module_name' => $name,
   'notes'       => { min_perl_version => $perl_ver, testing => $testing->() },
   %{ $prereqs },

)->create_build_script;

exit 0;

__DATA__

sub _added_to_INC { # CVE-2016-1238
  my $self = shift; my %seen;

  for ($self->_default_INC) { $seen{ $_ }++ }

  return grep { not $seen{ $_ }++ } $self->base_dir, @INC;
}
