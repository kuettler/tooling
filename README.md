Simple Tooling for C++ Code
===========================

Various small tools that help with C++ code editing build on top of Facebook's
C++ Linter [flint](https://github.com/facebook/flint). It's `Tokenizer.d` is
the basis of this whole endeavor.

This is all an exercise with D's ranges.

Central idea
------------

We get an array of proper C++ tokens thanks to `Tokenizer.d`, from which the
original file (with all whitespace and comments) can be recreated. Based on
this list we create a nested structure of `Entity` objects by looking for
pairs for curly braces in `Scanner.d`. To each pair of braces there is a
"header", which describes the type: namespace, class, function, enum,
etc. There is more and any complication can happily be ignored.

The key here is to map the list of tokens to the tree of `Entity` objects. At
this point various custom ranges can be used to transform the tokens.

Utilities
---------

Currently there are

- `CxxImplement.d`: Given a header/source file pair, add new functions from header to source
- `CxxMerge.d`: Merge multiple C++ files while preserving the namespace structure
- `CxxSortFunctions.d`: Sort functions by name while preserving the namespace structure
- `CxxAutoAuto.d`: Rewrite expressions that look like variable definitions to use the `auto` keyword

These utils are very specific and will not work on your files.

Custom Ranges
-------------

The custom ranges are the fun stuff.

- `MergedRange.d`: Merge multiple token arrays into one
- `SortRange.d`: Sort functions with namespaces in token array
- `TokenRange.d`: Map tokens to entities
- `TreeRange.d`: Make a range out of a nested tree structure
- `UnifyRange.d`: Unify functions in namespaces

License
-------

Distributed under the Boost license.
