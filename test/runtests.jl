using ObservationDims
using AxisArrays
using Distributions
using DataFrames
using LinearAlgebra
using NamedDims
using Random
using Test

@testset "ObservationDims.jl" begin

    @testset "_default_obsdim" begin

        for T in (Number, Sampleable, Symbol, AbstractArray, AbstractMatrix)
            @test ObservationDims._default_obsdim(T) == 1
        end

        x = rand(2, 2)
        @test ObservationDims._default_obsdim(NamedDimsArray{(:a, :observations)}(x)) == :observations
        @test ObservationDims._default_obsdim(NamedDimsArray{(:a, :obs)}(x)) == :obs
        @test ObservationDims._default_obsdim(NamedDimsArray{(:a, :samples)}(x)) == :samples

        y = rand(3, 3, 3)
        @test ObservationDims._default_obsdim(NamedDimsArray{(:a, :samples, :obs)}(y)) == :obs
        @test ObservationDims._default_obsdim(NamedDimsArray{(:a, :obs, :samples)}(y)) == :obs

        z = rand(4, 4, 4, 4)
        @test ObservationDims._default_obsdim(NamedDimsArray{(:samples, :a, :obs, :b)}(z)) == :obs

        @test_throws DimensionMismatch ObservationDims._default_obsdim(NamedDimsArray{(:a, :b, :c)}(y))

    end

    @testset "organise_obs" begin

        c_organise_obs(args...; kwargs...) = collect(organise_obs(args...; kwargs...))

        @testset "Simple Scalars" begin
            for (raw, arrange) in zip(
                (Normal(), 2, :test),
                (IteratorOfObs(), MatrixRowsOfObs(), MatrixColsOfObs())
            )
                @test raw == organise_obs(arrange, raw)
            end
        end

        @testset "Simple SingleObs" begin

            data = (
                1.2,
                [1, 2, 3],
                [[1, 2, 3], [4, 5, 6]],
                [[1 2 3; 10 20 30], [4 5 6; 40 50 60]],
                Normal(1, 3),
                MvNormal(rand(3), I)
            )

            # SingleObs should basically do nothing to these data
            @test all(==(raw, organise_obs(SingleObs(), raw)) for raw in data)

        end

        @testset "Simple IteratorOfObs for Iterators" begin
            for out in (
                [1, 2, 3],
                [[1, 2, 3], [4, 5, 6]],
                [[1 2 3; 10 20 30], [4 5 6; 40 50 60]],
            )
                for transform in (identity, Tuple, x->Base.Generator(identity, x))
                    raw = transform(out)
                    @test out == c_organise_obs(IteratorOfObs(), raw)
                end
            end
        end

        @testset "Simple IteratorOfObs for Vectors" begin
            raw = [1, 2, 3]
            @test raw == c_organise_obs(IteratorOfObs(), raw)

            raw = 1:10
            @test collect(raw) == c_organise_obs(IteratorOfObs(), raw)
        end

        @testset "Iterators to $Arrange" for (Arrange, out) in (
            (MatrixRowsOfObs(),  [10 20 30; 40 50 60]),
            (MatrixColsOfObs(), [10 40; 20 50; 30 60]),
        )
            raw = [[10, 20, 30], [40, 50, 60]]

            for transform in (identity, Tuple, x->Base.Generator(identity, x))
                data_iter = transform(raw)
                @test out == c_organise_obs(Arrange, data_iter)
            end
        end


        @testset "Matrices to $Arrange" for (Arrange, out) in (
            (IteratorOfObs(), [[1,2,3],[4,5,6]]),
            (MatrixRowsOfObs(), [1 2 3; 4 5 6]),
            (MatrixColsOfObs(), [1 4; 2 5; 3 6]),
        )
            raw = [1 2 3; 4 5 6]
            @test out == c_organise_obs(Arrange, raw)  # default is rows
            @test out == c_organise_obs(Arrange, raw; obsdim=1)
            @test out == c_organise_obs(Arrange, raw'; obsdim=2)
            @test out == c_organise_obs(Arrange, NamedDimsArray{(:obs, :var)}(raw))
            @test out == c_organise_obs(Arrange, NamedDimsArray{(:var, :obs)}(raw'))
            @test out == c_organise_obs(Arrange, NamedDimsArray{(:x, :y)}(raw'); obsdim=:y)
            @test out == c_organise_obs(Arrange, NamedDimsArray{(:x, :y)}(raw); obsdim=:x)

            A = AxisArray(raw, Axis{:y}([:t1, :t2]), Axis{:x}([:o1, :o2, :o3]))
            @test out == c_organise_obs(Arrange, A)
            @test out == c_organise_obs(Arrange, A; obsdim=1)
            @test out == c_organise_obs(Arrange, A; obsdim=:y)

            A = AxisArray(raw', Axis{:x}([:o1, :o2, :o3]), Axis{:y}([:t1, :t2]))
            @test out == c_organise_obs(Arrange, A; obsdim=2)
            @test out == c_organise_obs(Arrange, A; obsdim=:y)

        end

        @testset "ArraySlicesOfObs" begin
            raw = rand(4, 5, 6)

            # obsdim = 1 is default so raw data is already in arranged as expected: (1, 2, 3)
            @test organise_obs(ArraySlicesOfObs{1}(), raw) == raw
            @test organise_obs(ArraySlicesOfObs{1}(), raw) == organise_obs(MatrixRowsOfObs(), raw)

            # obsdim = 2 transposes each sub-matrix along dims 1 and 2: (2, 1, 3)
            @test organise_obs(ArraySlicesOfObs{2}(), raw) == organise_obs(MatrixColsOfObs(), raw)

            # obsdim = 3 transposes each sub-matrix along dims 1 and 3: (3, 2, 1)
            reorg_data = organise_obs(ArraySlicesOfObs{3}(), raw)
            @test reorg_data[1, :, :] == permutedims(raw[:, :, 1])
            @test reorg_data[:, 1, :] == permutedims(raw[:, 1, :])  # dim 2 is just transposed
            @test reorg_data[:, :, 1] == permutedims(raw[1, :, :])
        end

    end

    @testset "obs_arrangement $a" for a in (
        SingleObs(),
        IteratorOfObs(),
        MatrixRowsOfObs(),
        MatrixColsOfObs(),
    )

        foo(x) = x
        raw = [1 2 3; 4 5 6]

        # Overload obs_arrangement to specify the ObsArrangement
        ObservationDims.obs_arrangement(::typeof(foo)) = a
        @test obs_arrangement(foo) == a

        @test organise_obs(foo, raw) == organise_obs(a, raw)

    end

    @testset "Tables.jl support" begin
        nt_table = [(a=1, b=2, c=3), (a=10, b=20, c=30)]  # basic row table
        df = DataFrame(nt_table)  # advanced column table

        @testset "$(typeof(table))" for table in (df, nt_table)
            @test collect(organise_obs(IteratorOfObs(), table)) == [[1, 2, 3], [10, 20, 30]]
            @test organise_obs(MatrixRowsOfObs(), table) == [1 2 3; 10 20 30]
            @test organise_obs(MatrixColsOfObs(), table) == [1 10; 2 20; 3 30]

            for arrangement in (MatrixColsOfObs(), MatrixRowsOfObs(), IteratorOfObs())
                @test_logs(
                    (:warn, r"obsdim not equal to 1"),
                    organise_obs(arrangement, table; obsdim=20)
                )
            end
        end
    end
end
