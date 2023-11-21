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

Defines no public attributes

# Subroutines/Methods

Defines no public methods

# Diagnostics

None

# Dependencies

- [Moo](https://metacpan.org/pod/Moo)
- [Class::Usul::Cmd::Options](https://metacpan.org/pod/Class%3A%3AUsul%3A%3ACmd%3A%3AOptions)

# Incompatibilities

There are no known incompatibilities in this module

# Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-Usul-Cmd.
Patches are welcome

# Acknowledgements

Larry Wall - For the Perl programming language

# Author

Peter Flanigan, `<pjfl@cpan.org>`

# License and Copyright

Copyright (c) 2023 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic)

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE
