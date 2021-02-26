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

    @testset "@cached_call" begin
        @testset "f()" begin
            f() = 2
            @test f() == @cached_call(f()) == @cached_call f() # test first and second call
        end

        @testset "f(a, b)" begin
            f(a, b) = a + b
            @test f(1, 2) == @cached_call f(1, 2)
            @test f(1, 2) != @cached_call f(2, 2)
        end

        @testset "f(;kw=kw)" begin
            f(;kw=1) = kw
            call1 = @cached_call f(;kw=1)
            call2 = @cached_call f(kw=1)
            kw = 1
            if VERSION >= v"1.5"
                call3 = @cached_call f(;kw)
                @test f(;kw=1) == call1 == call2 == call3
            else
                @test f(;kw=1) == call1 == call2
            end
        end

        @testset "f(;kw=kw)" begin
            f(a; kw=1) = a - kw
            a = 2.0
            kw = 1
            call1 = @cached_call f(a; kw=1)
            if VERSION >= v"1.5"
                call2 = @cached_call f(a; kw)
                @test f(a; kw=1) == call1 == call2
            else
                @test f(a; kw=1) == call1
            end
        end

    end
end
