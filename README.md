Simple Tooling for C++ Code
===========================

Various small tools that help with C++ code editing build on top of Facebook's C++ Linter `flint`

`flint` is published at https://github.com/facebook/flint. It's
`Tokenizer.d` is the basis of this whole project.

Fun with D ranges
-----------------

This is all about D ranges and the fun to create something with it.

Central idea
------------

We get an array of proper C++ tokens thanks to `Tokenizer.d`. Based on this we
create a nested structure of `Entity` objects by looking for pairs for curly
braces in `Scanner.d`.

At this point various custom ranges can be used to transform the tokens and
entities.

Utilities
---------

- `CxxImplement.d`: Given a header/source file pair, add new functions from header to source
- `CxxMerge.d`: Merge multiple C++ files while preserving the namespace structure
- `CxxSortFunctions.d`: Sort functions by name while preserving the namespace structure

These utils are very specific and will not work on your files.

Custom Ranges
-------------

- `MergedRange.d`: Merge multiple token arrays into one
- `SortRange.d`: Sort functions with namespaces in token array
- `TokenRange.d`: Map tokens to entities
- `TreeRange.d`: Make a range out of a nested tree structure
- `UnifyRange.d`: Unify functions in namespaces

License
-------

Distributed under the Boost license.
