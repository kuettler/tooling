Simple Tooling for C++ Code
===========================

Various small tools that help with C++ code editing build on top of Facebook's
C++ Linter [flint](https://github.com/facebook/flint). It's `Tokenizer.d` is
the basis of this whole endeavor.

This is all an exercise with D's ranges.

Utilities
---------

Currently there are

- `CxxImplement.d`: Given a header/source file pair, add new functions from header to source
- `CxxMerge.d`: Merge multiple C++ files while preserving the namespace structure
- `CxxSortFunctions.d`: Sort functions by name while preserving the namespace structure
- `CxxAutoAuto.d`: Rewrite expressions that look like variable definitions to use the `auto` keyword

These utils are very specific and will not work on your files.

License
-------

Distributed under the Boost license.
