# Name

Class::Usul::Cmd - Command line support framework

# Synopsis

    package Test;

    our $VERSION = 0.1;

    use Moo;
    use Class::Usul::Cmd::Options;

    extends 'Class::Usul::Cmd';

    option 'test_attr' => is => 'ro';

    sub test_method : method {
    }

    ...

    # In bin/test_script
    exit Test->new_with_options(config => Test::Config->new())->run;

    ...

    bin/test_script --test-attr foo test-method

# Description

Command line support framework

# Configuration and Environment

Defines the following attributes;

- `config`

    A required object reference used to provide configuration attributes. See
    the [config provider](https://metacpan.org/pod/Class%3A%3AUsul%3A%3ACmd%3A%3ATypes#ConfigProvider) type

- `l10n`

    An optional object reference which is used to localise text messages.  See the
    [localiser](https://metacpan.org/pod/Class%3A%3AUsul%3A%3ACmd%3A%3ATypes#Localiser) type

- `log`

    An object reference which defaults to [Class::Null](https://metacpan.org/pod/Class%3A%3ANull). See the
    [logger](https://metacpan.org/pod/Class%3A%3AUsul%3A%3ACmd%3A%3ATypes#Logger) type

# Subroutines/Methods

- `BUILDARGS`

    If the constructor is called with a `builder` attribute (either an object
    reference or a hash reference) it's `config`, `l10n`, and `log` attributes
    are used to instantiate the attributes of the same name in this class

- `has_l10n`

    Predicate

# Diagnostics

None

# Dependencies

- [Moo](https://metacpan.org/pod/Moo)

# Incompatibilities

There are no known incompatibilities in this module

# Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-Usul-Cmd.
Patches are welcome

# Acknowledgements

Larry Wall - For the Perl programming language

# Author

Peter Flanigan, `<lazarus@roxsoft.co.uk>`

# License and Copyright

Copyright (c) 2023 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic)

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE
