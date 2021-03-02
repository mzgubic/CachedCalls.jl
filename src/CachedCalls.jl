module CachedCalls

using FilePathsBase
using FilePathsBase: /
using JLSO

export @cached_call, @hash_call
export cachedcalls_dir

const CACHEDCALLS_PATH = Ref{PosixPath}()

"""
    @cached_call f(args; kwargs)

Caches the result of `f(args; kwargs)` to disk and returns the result. The next time
`f(args; kwargs)` is called with the same values of `args` and `kwargs` the cached result
is returned and `f` is not called again. Splatting it not yet supported.

Restrictions on `f` apply: it must not mutate its arguments or access/mutate globals.
These assumptions will not be checked and if violated could mean that an incorrect
result is returned.

Functions are differentiated by name only, meaning that changing the definition and
rerunning `@cached_call` will return the wrong result.
"""
macro cached_call(ex)
    return quote
        h = @hash_call $(esc(ex))

        fname = $(cachedcalls_dir()) / "$(h).jlso"
        if isfile(fname)
            res = JLSO.load(fname)[:res]
        else
            res = $(esc(ex))
            JLSO.save(fname, :res => res)
        end
        res
    end
end

"""
    @hash_call f(args; kwargs)

Computes the hash of the function call `f(args; kwargs)` by hashing `f`, the values of
`args`, the names of `kwargs`, and the values of `kwargs`.

Different order of kwargs will hash differently. Setting the default values of kwargs
explicitly will hash differently than using the defaults implicitly. Splatting it not yet
supported.
"""
macro hash_call(ex)
    func, args, kw_names, kw_values = _deconstruct(ex)

    return :(hash([
        $(esc(func)), # function name
        $(esc.(args)...), # arg values
        $(kw_names)..., # kwarg names
        $(esc.(kw_values)...) # kwarg values
    ]))
end

"""
    cachedcalls_dir()

Retrieves the path to where the cached files are stored.
"""
function cachedcalls_dir()
    if !isassigned(CACHEDCALLS_PATH)
        CACHEDCALLS_PATH[] = PosixPath(first(Base.DEPOT_PATH)) / ".cachedcalls"
    end

    isdir(CACHEDCALLS_PATH[]) || mkdir(CACHEDCALLS_PATH[])

    return CACHEDCALLS_PATH[]
end

"""
    cachedcalls_dir(p::Union{String, PosixPath})

Sets the path to where the cached files are stored to `p`.
"""
function cachedcalls_dir(p::PosixPath)
    CACHEDCALLS_PATH[] = p
end
function cachedcalls_dir(p::String)
    CACHEDCALLS_PATH[] = PosixPath(p)
end

"""
    _deconstruct(ex)

Deconstruct expression `ex` to a tuple (function name, arguments, kwarg names, kwarg values)
"""
function _deconstruct(ex)
    # escaped expressions need their unescaped subexpression deconstructed
    isesc = Meta.isexpr(ex, :escape)
    if isesc
        nonesc_ex = ex.args[1]
    else
        nonesc_ex = ex
    end

    # check assumptions about the call
    Meta.isexpr(nonesc_ex, :call) || error("Only :call expressions are supported, $ex was given.")

    # Extract arguments, kwarg names, and kwarg values.
    func, fargs = Iterators.peel(nonesc_ex.args)

    args = filter(subex -> !Meta.isexpr(subex, [:kw, :parameters]), collect(fargs))
    kwargs = _extract_kwargs(collect(fargs))
    kw_names = first.(kwargs)
    kw_values = last.(kwargs)

    # If the original expression was escaped, we have extracted the non-escaped expression
    # to deconstruct, and must escape the indvidual expression components instead.
    if isesc
        args = esc.(args)
        kw_values = esc.(kw_values)
        func = esc(func)
    end

    return func, args, kw_names, kw_values
end

"""
    _extract_kwargs(callargs::AbstractArray{Any}; keep_args=false)

Extract a tuple of (:kwarg_name, value) from :call expression args.
"""
function _extract_kwargs(x; keep_args=false)
    return keep_args ? [(x, x)] : []
end

function _extract_kwargs(ex::Expr; keep_args=false)
    # kwargs specified without ;
    if Meta.isexpr(ex, :kw)
        return [(ex.args[1], ex.args[2]),]

    # kwargs specified with ;
    elseif Meta.isexpr(ex, :parameters)
        # need to `keep_args` because of `f(;c)` syntactic sugar does not result in :kw
        # expression but in a single arg :c to parameters
        return [(_extract_kwargs.(ex.args; keep_args=true)...)...]

    # container.key or container[index] access
    elseif Meta.isexpr(ex, [:., :ref])
        return keep_args ? [(ex, ex)] : []

    else
        error("Unexpected input expression to _extract_kwargs: $ex")
    end
end

function _extract_kwargs(a::AbstractArray; keep_args=false)
    return [(_extract_kwargs.(a)...)...]
end

end
