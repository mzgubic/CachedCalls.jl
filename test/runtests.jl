using CachedCalls
using Test

@testset "CachedCalls.jl" begin
    @testset "_deconstruct" begin
        @testset "f(1, 2, c)" begin
            ex = :(f(1, 2, c))
            func, args, kw_names, kw_values = CachedCalls._deconstruct(ex)
            @test func == :f
            @test args == Any[1, 2, :c]
            @test kw_names == Any[]
            @test kw_values == Any[]
        end

        @testset "f(;a=1, b=2, c)" begin
            ex = :(f(; a=1, b=2, c))
            func, args, kw_names, kw_values = CachedCalls._deconstruct(ex)
            @test func == :f
            @test args == Any[]
            @test kw_names == [:a, :b, :c]
            @test kw_values == [1, 2, :c]
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

    @testset "@cached_call and @hash_call" begin
        @testset "f()" begin
            f() = 2
            call1 = @cached_call f()
            call2 = @cached_call f()
            @test f() == call1 == call2

            @test @hash_call(f()) isa UInt
        end

        @testset "f(a, b)" begin
            f(a, b) = a + b
            a = 1
            @test f(a, 2) == @cached_call f(a, 2)
            @test f(a, 2) != @cached_call f(2, 2)

            @test @hash_call(f(a, 2)) isa UInt
        end

        @testset "f(;kw=kw)" begin
            f(;kw=1) = kw
            call1 = @cached_call f(;kw=1)
            call2 = @cached_call f(kw=1)
            kw = 1

            @test @hash_call(f(;kw=1)) isa UInt
            @test @hash_call(f(kw=1)) isa UInt

            @static if VERSION >= v"1.5"
                call3 = @cached_call f(;kw)
                @test f(;kw=1) == call1 == call2 == call3
                @test @hash_call(f(;kw)) isa UInt
            else
                @test f(;kw=1) == call1 == call2
            end
        end

        @testset "f(a ;kw=kw)" begin
            f(a; kw=1) = a - kw
            a = 2.0
            kw = 1
            @test f(a; kw=kw) == @cached_call f(a; kw=kw)
            @test @hash_call(f(a; kw=kw)) isa UInt
        end

        @testset "dot access" begin
            f(a; kw=0) = a + kw
            nt = (one=1, two=2)
            @test f(1, kw=2) == @cached_call f(nt.one; kw=nt.two)
            @test f(1, kw=2) == @cached_call f(nt.one, kw=nt.two)
            @test @hash_call(f(nt.one; kw=nt.two)) isa UInt
        end

        @testset "square bracket access" begin
            f(a; kw=0) = a + kw

            array = [1, 2, 3]
            call1 = @cached_call f(array[1]; kw=array[2])
            call2 = @cached_call f(array[1], kw=array[2])
            @test f(1, kw=2) == call1 == call2
            @test @hash_call(f(array[1], kw=array[2])) isa UInt

            array = [10, 20, 30]
            call3 = @cached_call f(array[1]; kw=array[2])
            call4 = @cached_call f(array[1], kw=array[2])
            @test call1 != call3
            @test call2 != call4
        end

        @testset "splatting" begin
            f(a, b; kw1=1, kw2=2) = a + b + kw1 + kw2

            one = 1
            a = [1, 2]
            kw = (kw1=1, kw2=2)

            @testset "basic splatting" begin
                @test f(a...) == @cached_call f(a...)
                @test f(a...) == @cached_call f([1, 2]...)
                @test f(a...) == @cached_call f([one, 2]...)
                @test f(a...; kw...) == @cached_call f(a...; kw...)
                @test f(a...; kw...) == @cached_call f(a...; (kw1=1, kw2=2)...)
                @test f(a...; kw...) == @cached_call f(a...; (kw1=one, kw2=2)...)

                @test @hash_call(f(a...)) isa UInt
                @test @hash_call(f([1, 2]...)) isa UInt
                @test @hash_call(f([one, 2]...)) isa UInt
                @test @hash_call(f(a...; kw...)) isa UInt
                @test @hash_call(f(a...; (kw1=1, kw2=2)...)) isa UInt
                @test @hash_call(f(a...; (kw1=one, kw2=2)...)) isa UInt
            end

            @testset "different containers" begin
                call1 = @cached_call f(1, 2)
                call2 = @cached_call f([1, 2]...)
                call3 = @cached_call f((1, 2)...)
                @test call1 == call2 == call3

                @test @hash_call(f([1, 2]...)) isa UInt
                @test @hash_call(f((1, 2)...)) isa UInt
            end

            @testset "make sure we hash splatted values (not variable names)" begin
                a = [1, 2]
                call4 = @cached_call f(a...)
                a = [10, 20]
                call5 = @cached_call f(a...)
                @test call4 != call5

                kw = (kw1=1, kw2=2)
                call6 = @cached_call f(1, 2; kw...)
                kw = (kw1=10, kw2=20)
                call7 = @cached_call f(1, 2; kw...)
                @test call6 != call7
            end
        end
    end
end
