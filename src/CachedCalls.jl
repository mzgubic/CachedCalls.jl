module CachedCalls

using FilePathsBase
using FilePathsBase: /
using JLSO

const CACHEDCALLS_DIR = home() / ".cachedcalls"
isdir(CACHEDCALLS_DIR) || mkdir(CACHEDCALLS_DIR)

export @cached_call

macro cached_call(ex)
    Meta.isexpr(ex, :call) || error("Invalid use of `@cached_call`")

    func, args, kwargs = _deconstruct(ex)
    kw_names = first.(kwargs)
    kw_values = last.(kwargs)

    return quote
        h = hash([
            $(esc(func)), # function name
            $(esc.(args)...), # arg values
            $(kw_names)..., # kwarg names
            $(esc.(kw_values)...) # kwarg values
        ])
        fname = $(CACHEDCALLS_DIR) / "$(h).jlso"
        if isfile(fname)
            return JLSO.load(fname)[:res]
        else
            res = $(esc(ex))
            JLSO.save(fname, :res => res)
            return res
        end
    end
end

function _deconstruct(ex)
    func, fargs = Iterators.peel(ex.args)
    length(ex.args) == 1 && return func, [], []

    args = filter(subex -> !Meta.isexpr(subex, [:kw, :parameters]), collect(fargs))
    kwargs = _extract_kwargs(collect(fargs))
    return func, args, kwargs
end
function _extract_kwargs(x; keep=false)
    return keep ? [(x, x)] : []
end
function _extract_kwargs(ex::Expr; keep=false)
    if Meta.isexpr(ex, :kw)
        return [(ex.args[1], ex.args[2]),]
    elseif Meta.isexpr(ex, :parameters)
        return [(_extract_kwargs.(ex.args; keep=true)...)...]
    else
        error("Unexpected input expression to _extract_kwargs: $ex")
    end
end
function _extract_kwargs(a::AbstractArray; keep=false)
    return [(_extract_kwargs.(a)...)...]
end
end
