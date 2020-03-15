# ObservationDims

[![Build Status](https://travis-ci.com/invenia/ObservationDims.jl.svg?branch=master)](https://travis-ci.com/invenia/ObservationDims.jl)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/invenia/ObservationDims.jl?svg=true)](https://ci.appveyor.com/project/invenia/ObservationDims-jl)
[![Codecov](https://codecov.io/gh/invenia/ObservationDims.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/invenia/ObservationDims.jl)

# What are ObservationDims?

This package defines useful traits and methods for organising data into the format required by some API.

## Organising data

Imagine we have some matrix of data that we want to pass to a model.
The model may require that observations correspond to matrix rows, or perhaps that they correspond to matrix columns.
Another model might treat the matrix itself as a single observation.

We want to make sure each model parses the data in the correct format.
For this, we can use `organise_obs` to reorganise the data (when necessary) into the required `ObsArrangement`.

```julia
using ObservationDims

# treat whole matrix as one observation
organise_obs(SingleObs(), data)

# rearrange matrix such that observations are columns and rows are features
organise_obs(MatrixColsOfObs(), data)
```

By default, observations are assumed to belong to the first dimension (i.e. rows).
This can be over-written using the `obsdim` keyword argument:

```julia
# rearrange into a vector of observations where observations are along the 2nd dimension (cols)
organise_obs(IteratorOfObs(), data; obsdim=2)
```

### N-Dimensional data
The `MatrixRowsOfObs` and `MatrixColsOfObs` are special cases of the more general `ArraySlicesOfObs{D}` where `D` is the desired observation-dimension.
(`D=1` for `MatrixRowsOfObs` and `D=2` for `MatrixColsOfObs`).

For example, if we have a 4-dimensional `Array` with the observations along the 1st dimension but we require them along the 4th dimension we can permute the 1st and 4th dimensions, e.g. `(1, 2, 3, 4) -> (4, 2, 3, 1)`, as follows:

```julia
organise_obs(ArraySlicesOfObs{4}(), data; obsdim=1)
```

### NamedDimsArrays and AxisArrays

When used with `NamedDimsArray`s and `AxisArray`s, the `obsdim` can also be a symbol.

For `NamedDimsArray`s, the default `obsdim` is selected from `(:obs, :observations, :samples)` in order of preference.
For example, `:obs` will always be selected if present, else `:observations` will selected if present, else `:samples` will be selected.
If none of these are present you will be required to explicitly provide the `obsdim` yourself.
This does not apply to `AxisArray`s, which like `AbstractArray` in general, default to `obsdim=1`.

```julia
# no fields are named :obs, :observations, or :samples
organise_obs(MatrixRowsOfObs(), named_dims; obsdim=:time)
```

### Tables
[Tables.jl](https://github.com/JuliaData/Tables.jl) tables, such as [DataFrames](https://github.com/JuliaData/DataFrames.jl/), are supported as an input.
The observations for a table are always the rows, i.e. `obsdim=1` (warning will be given if you specify otherwise).
The table will be converted into a matrix or iterator of vectors as appropriate.

## Method Traits

The key purpose of this package is to make all of this easier by specifying the `ObsArrangement` as a trait of the model.
We do this using `obs_arrangement` to declare the expected `ObsArrangement`:

```julia
# model1 takes data with rows as observations
obs_arrangement(::typeof(model1)) = MatrixRowsOfObs

# model2 takes data as an iterator of observations
obs_arrangement(::typeof(model2)) = IteratorOfObs
```

Now `organise_obs` can take the model as an argument which will then dispatch on the trait and organise the data accordingly:

```julia
# rearranges data to use rows as observations
model1_data = organise_obs(model1, data)

# rearranges data as an iterator of observations
model2_data = organise_obs(model2, data)
```
