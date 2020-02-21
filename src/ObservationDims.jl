module ObservationDims

using AxisArrays
using Compat
using Distributions
using NamedDims
using Tables

export obs_arrangement, organise_obs
export SingleObs, IteratorOfObs, ArraySlicesOfObs
export MatrixRowsOfObs, MatrixColsOfObs

"""
    type ObsArrangement

Defines the orientation of data that is expected by a function
"""
abstract type ObsArrangement end

"""
    SingleObs <: ObsArrangement

The data consists of a single observation regardless of dimension.
"""
struct SingleObs <: ObsArrangement end

"""
    IteratorOfObs <: ObsArrangement

The data consists of an iterator over multiple observations.
"""
struct IteratorOfObs <: ObsArrangement end

"""
    ArraySlicesOfObs{D} <: ObsArrangement

The data consists of a multi-dimensional array where the observations are along dimension `D`.
"""
struct ArraySlicesOfObs{D} <: ObsArrangement end

"""
    MatrixRowsOfObs <: ObsArrangement

A special case of `ArraySlicesOfObs` where the observations are along the first dimension.
"""
const MatrixRowsOfObs = ArraySlicesOfObs{1}

"""
    MatrixColsOfObs <: ObsArrangement
A special case of `ArraySlicesOfObs` where the observations are along the second dimension.
"""
const MatrixColsOfObs = ArraySlicesOfObs{2}


"""
    obs_arrangement(f::Type{<:Function}) -> ObsArrangement

Specify the observation arrangement trait of a function `f`.
"""
function obs_arrangement end

"""
    _TableHolder

A internal wrapper type for dispatch purposes.
Since tables do not have a type, wrap them in this so we can dispatch on them.
"""
struct _TableHolder{T}
    data::T
end
"""
    organise_obs(f, data; obsdim=nothing)
    organise_obs(::ObsArrangement, data; obsdim=nothing)

Organise the `data` according to the `ObsArrangement` expected by `f`.

# Arguments
- `f`: the function or method needing the data in a certain orientation
- `data`: the data to transform
- `obsdim`: the dimension of the observations
"""
function organise_obs(f, data; obsdim=_default_obsdim(data))
    return organise_obs(obs_arrangement(f), data; obsdim=obsdim)
end


# Specify arrangement based on type of data:

# Scalars have no "orientation" so no rearrangement required
for T in (Sampleable, Number, Symbol)
    @eval organise_obs(::SingleObs, data::$T; obsdim=nothing) = data
    @eval organise_obs(::IteratorOfObs, data::$T; obsdim=nothing) = data
    @eval organise_obs(::ArraySlicesOfObs, data::$T; obsdim=nothing) = data
end

## Vectors: obsdim is optional, we may or may not need it.
for T in (Any, AbstractVector)
    # Iterator -> IteratorOfObs
    @eval function organise_obs(::IteratorOfObs, obs_iter::$T; obsdim=nothing)
        if Tables.istable(obs_iter)
            return organise_obs(IteratorOfObs(), _TableHolder(obs_iter); obsdim=obsdim)
        else
            return obs_iter
        end
    end

    # Iterator -> ArraySlicesOfObs
    @eval function organise_obs(::ArraySlicesOfObs{D}, obs_iter::$T; obsdim=nothing) where D
        if Tables.istable(obs_iter)
            return organise_obs(ArraySlicesOfObs{D}(), _TableHolder(obs_iter); obsdim=obsdim)
        end
        # we assume all obs have same number of dimensions else nothing makes sense
        ndims_per_obs = ndims(first(obs_iter))

        # If collection of scalars then return the collection
        if ndims_per_obs == 0
            return collect(obs_iter)
        end

        # This should just be a mapreduce but that is slow
        # see https://github.com/JuliaLang/julia/issues/31137
        shaped_obs = Base.Generator(obs_iter) do obs
            new_shape = ntuple(ndims_per_obs + 1) do ii
                if ii < D
                    size(obs, ii)
                elseif ii > D
                    size(obs, ii-1)
                else  # ii = D
                    1
                end
            end
            # add singleton dim that we wil concatenate on
            Base.ReshapedArray(obs, new_shape, ())
        end
        return cat(shaped_obs...; dims=D)
    end
end

# Specify arrangement based on desired ObsArrangement:

# Any -> SingleObs: never any need to rearrage
organise_obs(::SingleObs, data; obsdim=nothing) = data

# Tables support
function organise_obs(arrangement::IteratorOfObs, holder::_TableHolder; obsdim=1)
    _warn_about_table_obsdim(obsdim)
    data = holder.data
    return (collect(obs) for obs in Tables.rows(data))
end

function organise_obs(arrangement::ArraySlicesOfObs, holder::_TableHolder; obsdim=1)
    _warn_about_table_obsdim(obsdim)
    data = Tables.matrix(holder.data)
    return organise_obs(arrangement, data; obsdim=1)
end

function _warn_about_table_obsdim(obsdim)
    if obsdim !== 1 && obsdim !== nothing
        @warn "Arraying a Table, obsdim not equal to 1 ignored" obsdim
    end
end

# Array -> IteratorOfObs or ArraySlicesOfObs: depends on obsdim
# Resorts to default obsdim which redispatches to the 3 arg form below.
for A in (IteratorOfObs, ArraySlicesOfObs)

    @eval function organise_obs(arrangement::$A, data::AbstractArray; obsdim=_default_obsdim(data))
        return organise_obs(arrangement, data, obsdim)
    end

    @eval function organise_obs(arrangement::$A, data::NamedDimsArray; obsdim=_default_obsdim(data))
        obsdim = (obsdim isa Symbol) ? NamedDims.dim(data, obsdim) : obsdim
        return organise_obs(arrangement, data, obsdim)
    end

    @eval function organise_obs(arrangement::$A, data::AxisArray; obsdim=_default_obsdim(data))
        obsdim = (obsdim isa Symbol) ? axisdim(data, Axis{obsdim}) : obsdim
        return organise_obs(arrangement, data, obsdim)
    end
end

# 3 arg forms rearrange (non 1D) arrays according to the obsdim

# Slice up the array to get an iterator of observations
function organise_obs(::IteratorOfObs, data::AbstractArray, obsdim::Integer)
    return eachslice(data, dims=obsdim)
end

# Permute the array so the observations are arranged correctly
function organise_obs(
    ::ArraySlicesOfObs{D}, data::AbstractArray{<:Any, N}, obsdim::Integer
) where {D, N}

    if obsdim == D
        return data
    else
        # Swap around the obsdim with the dimension we want to assign it to
        perm = ntuple(N) do ii
            if ii == D
                return obsdim
            elseif ii == obsdim
                return D
            else
                return ii
            end
        end
        return PermutedDimsArray(data, perm)
    end
end

# Assign rows as observations by default
_default_obsdim(x) = 1
function _default_obsdim(x::NamedDimsArray{L}) where L
    obsnames = (:obs, :observations, :samples)

    # These obsnames specify the order of preference when returning your observation dimension
    # e.g. if :obs and :samples both exist in your NamedDimsArray then :obs is always returned
    used = findfirst(in(L), obsnames)
    if used === nothing
        throw(DimensionMismatch(string(
            "No observation dimension found. Provide one of the valid dimension names = $L."
        )))
    end
    return @inbounds obsnames[used]
end

end # module
