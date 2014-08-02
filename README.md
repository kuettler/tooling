tooling
=======

Various small tools that help with C++ code editing build on top of Facebook's C++ Linter `flint`

`flint` is published on Github at https://github.com/facebook/flint. It's
`Tokenizer.d` is the basis of this whole project.

The aim is to create a set of simple functions that can be build into special
purpose editing tools. There is no general solution to C++ refactoring,
however, much can be done with modest means.

`SortFunctions.d`: A C++ function sorter
----------------------------------------

Sorts all C++ functions in alphabetical order. This is the proof of concept
tool that makes the whole github project worthwhile and its author proud.

This is all there is at this point. There might be more to come.

Utils
-----

- `Tokenizer.d`: the tokenizer from facebook's `flint`
- `Scanner.d`: the reader that find matching pairs of braces and statement separations
- `TreeRange.d`: a depth-first tree input range

Some restrictions apply:

* The C++ code is assumed to be within an explicit namespace.
* The generated code might not compile

License
-------

Distributed under the Boost license.
