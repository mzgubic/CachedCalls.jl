using CachedCalls
using Documenter

makedocs(;
    modules=[CachedCalls],
    authors="Miha Zgubic <miha.zgubic@invenialabs.co.uk> and contributors",
    repo="https://github.com/mzgubic/CachedCalls.jl/blob/{commit}{path}#L{line}",
    sitename="CachedCalls.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)
