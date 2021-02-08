using CachedCalls
using Test

@testset "CachedCalls.jl" begin

    @testset "_deconstruct" begin
        @testset "f(1, 2, c)" begin
            ex = :(f(1, 2, c))
            func, args, kwargs = CachedCalls._deconstruct(ex)
            @test func == :f
            @test args == Any[1, 2, :c]
            @test kwargs == Any[]
        end

        @testset "f(;a=1, b=2, c)" begin
            ex = :(f(; a=1, b=2, c))
            func, args, kwargs = CachedCalls._deconstruct(ex)
            @test func == :f
            @test args == Any[]
            @test kwargs == Tuple{Symbol,Any}[(:a, 1), (:b, 2), (:c, :c)]
        end
    end

    @testset "_extract_kwargs" begin
        @test CachedCalls._extract_kwargs(:a) == []
        @test CachedCalls._extract_kwargs(:a; keep_args=true) == [(:a, :a)]
        @test CachedCalls._extract_kwargs(Expr(:kw, :a, 1)) == [(:a, 1),]
        @test CachedCalls._extract_kwargs(Expr(:kw, :a, :variable)) == [(:a, :variable),]

        @testset "f(a=1, b=2, c=3)" begin
            fargs = Any[:($(Expr(:kw, :a, 1))), :($(Expr(:kw, :b, 2))), :($(Expr(:kw, :c, 3)))]
            @test CachedCalls._extract_kwargs(fargs) == [(:a, 1), (:b, 2), (:c, 3)]
        end
        @testset "f(;a=1, b=2, c=3)" begin
            fargs = Any[:($(Expr(:parameters, :($(Expr(:kw, :a, 1))), :($(Expr(:kw, :b, 2))), :($(Expr(:kw, :c, 3))))))]
            @test CachedCalls._extract_kwargs(fargs) == [(:a, 1), (:b, 2), (:c, 3)]
        end

        @testset "f(;a=1, b=2, c)" begin
            fargs = Any[:($(Expr(:parameters, :($(Expr(:kw, :a, 1))), :($(Expr(:kw, :b, 2))), :c)))]
            @test CachedCalls._extract_kwargs(fargs) == [(:a, 1), (:b, 2), (:c, :c)]
        end
    end
end
