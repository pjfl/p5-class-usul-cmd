# This file is generated by Dist::Zilla::Plugin::CPANFile v6.030
# Do not edit this file directly. To change prereqs, edit the `dist.ini` file.

requires "Class::Inspector" => "1.36";
requires "Class::Null" => "2.110730";
requires "Data::Printer" => "1.001000";
requires "Data::Record" => "0.02";
requires "Exporter::Tiny" => "1.006000";
requires "File::DataClass" => "v0.73.5";
requires "Getopt::Long::Descriptive" => "0.111";
requires "IO::Interactive" => "1.023";
requires "JSON::MaybeXS" => "1.004004";
requires "Module::Runtime" => "0.016";
requires "Moo" => "2.005005";
requires "Pod::Eventual" => "0.094001";
requires "Ref::Util" => "0.204";
requires "Sub::Identify" => "0.14";
requires "Sub::Install" => "0.929";
requires "Term::ReadKey" => "2.38";
requires "Text::Autoformat" => "1.75";
requires "TimeDate" => "1.21";
requires "Try::Tiny" => "0.31";
requires "Type::Tiny" => "2.002001";
requires "Unexpected" => "v1.0.6";
requires "namespace::autoclean" => "0.29";
requires "namespace::clean" => "0.27";
requires "perl" => "5.010001";
requires "strictures" => "2.000006";

on 'build' => sub {
  requires "Module::Build" => "0.4004";
  requires "version" => "0.88";
};

on 'test' => sub {
  requires "File::Spec" => "0";
  requires "Module::Build" => "0.4004";
  requires "Module::Metadata" => "0";
  requires "Sys::Hostname" => "0";
  requires "Test::Requires" => "0.06";
  requires "version" => "0.88";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "2.120900";
};

on 'configure' => sub {
  requires "Module::Build" => "0.4004";
  requires "version" => "0.88";
};
