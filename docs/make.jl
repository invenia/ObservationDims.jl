using Documenter, ObservationDims

makedocs(;
    modules=[ObservationDims],
    format=Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"),
    pages=[
        "Home" => "index.md",
        "API" => "api.md",
    ],
    repo="https://github.com/invenia/ObservationDims.jl/blob/{commit}{path}#L{line}",
    sitename="ObservationDims.jl",
    authors="Invenia Technical Computing Corporation",
    assets=[
        "assets/invenia.css",
    ],
    strict = true,
    checkdocs = :none,
)

deploydocs(;
    repo="github.com/invenia/ObservationDims.jl",
)
