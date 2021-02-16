# CachedCalls

[![Build Status](https://github.com/mzgubic/CachedCalls.jl/workflows/CI/badge.svg)](https://github.com/mzgubic/CachedCalls.jl/actions)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

Functions that take a long time to run can slow down experimentation and code development.
Instead of running the same function with the same inputs multiple times, the result can be cached to disk and fetched when the function is run with the same arguments again.
A simple macro provides this functionality:

```julia
using CachedCalls

@cached_call f(args; kwargs)
```

It works by hashing the macro name, values of arguments, and names and values of keyword arguments.

## Gotchas
A few things to consider before using the macro:

- Is `f` accessing global variables?

The second time the macro is used the returned result may be unexpected (if the global variable has changed)

- Is `f` mutating its inputs or global variables?

The second time the macro is used the inputs/globals will not be mutated.

- The inputs to the macro are considered the same if their hashes are the same.

Notably, `hash(1) == hash(1.0)`, and similarly for `DataFrame`s that differ only by column names.
Additionally, function arguments are differentiated by name only.
