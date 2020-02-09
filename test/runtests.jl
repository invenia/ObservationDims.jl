using ObservationDims
using AxisArrays
using Distributions
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

      @testset "SingleObs" begin

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

      @testset "simple IteratorOfObs for iterators" begin
          for out in (
              [1,2,3],
              [[1,2,3], [4,5,6]],
              [[1 2 3; 10 20 30], [4 5 6; 40 50 60]],
          )
              for transform in (identity, Tuple, x->Base.Generator(identity, x))
                  raw = transform(out)
                  @test out == c_organise_obs(IteratorOfObs(), raw)
              end
          end
      end

      @testset "iterators to $Arrange" for (Arrange, out) in (
          (MatrixRowsOfObs(),  [10 20 30; 40 50 60]),
          (MatrixColsOfObs(), [10 40; 20 50; 30 60]),
      )
          raw = [[10, 20, 30], [40, 50, 60]]

          for transform in (identity, Tuple, x->Base.Generator(identity, x))
              data_iter = transform(raw)
              @test out == c_organise_obs(Arrange, data_iter)
          end
      end


      @testset "matrix to $Arrange" for (Arrange, out) in (
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
      end
  end


end
