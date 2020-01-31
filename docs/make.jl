using Documenter, ObservationDims

makedocs(;
    modules=[ObservationDims],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/invenia/ObservationDims.jl/blob/{commit}{path}#L{line}",
    sitename="ObservationDims.jl",
    authors="Invenia Technical Computing Corporation",
    assets=[
        "assets/invenia.css",
        "assets/logo.png",
    ],
)

deploydocs(;
    repo="github.com/invenia/ObservationDims.jl",
)
