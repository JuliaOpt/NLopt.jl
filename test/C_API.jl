# Copyright (c) 2013: Steven G. Johnson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module TestCAPI

using NLopt
using Test

function runtests()
    for name in names(@__MODULE__; all = true)
        if !startswith("$(name)", "test_")
            continue
        end
        @testset "$(name)" begin
            getfield(@__MODULE__, name)()
        end
    end
    return
end

function test_issue_163()
    opt = Opt(:LN_COBYLA, 2)
    opt.min_objective = (x, g) -> sum(x .^ 2)
    inequality_constraint!(opt, 2, (result, x, g) -> (result .= 1 .- x))
    (minf, minx, ret) = optimize(opt, [2.0, 2.0])
    @test minx ≈ [1.0, 1.0]
    return
end

function test_issue_132()
    opt = Opt(:LN_COBYLA, 2)
    err = ErrorException(
        "Getting `initial_step` is unsupported. Use " *
        "`initial_step(opt, x)` to access the initial step at a point `x`.",
    )
    @test_throws err opt.initial_step
    return
end

function test_issue_156_CapturedException()
    f(x, g = []) = (error("test error"); x[1]^2)
    opt = Opt(:LN_SBPLX, 1)
    opt.min_objective = f
    @test_throws CapturedException optimize(opt, [0.1234])
    @test NLopt.nlopt_exception === nothing
    try
        optimize(opt, [0.1234])
    catch e
        # Check that the backtrace is being printed
        @test length(sprint(show, e)) > 100
    end
    return
end

function test_issue_156_ForcedStop()
    f(x, g = []) = (throw(NLopt.ForcedStop()); x[1]^2)
    opt = Opt(:LN_SBPLX, 1)
    opt.min_objective = f
    fmin, xmin, ret = optimize(opt, [0.1234])
    @test ret == :FORCED_STOP
    @test NLopt.nlopt_exception === nothing
    return
end

function test_issue_156_no_error()
    f(x, g = []) = (x[1]^2)
    opt = Opt(:LN_SBPLX, 1)
    opt.min_objective = f
    fmin, xmin, ret = optimize(opt, [0.1234])
    @test ret ∈ (:SUCCESS, :FTOL_REACHED, :XTOL_REACHED)
    @test NLopt.nlopt_exception === nothing
    return
end

function test_invalid_algorithms()
    @test_throws ArgumentError("unknown algorithm: BILL") Algorithm(:BILL)
    @test_throws ArgumentError("unknown algorithm: BILL") Opt(:BILL, 420)
    return
end

function test_issue_133()
    function rosenbrock(x::Vector, grad::Vector)
        if length(grad) > 0
            grad[1] = -400 * x[1] * (x[2] - x[1]^2) - 2 * (1 - x[1])
            grad[2] = 200 * (x[2] - x[1]^2)
        end
        return (1 - x[1])^2 + 100 * (x[2] - x[1]^2)^2
    end
    function ineq01(x::Vector, grad::Vector)
        if length(grad) > 0
            grad[1] = 1
            grad[2] = 2
        end
        return x[1] + 2 * x[2] - 1
    end
    function ineq02(x::Vector, grad::Vector)
        if length(grad) > 0
            grad[1] = 2 * x[1]
            grad[2] = 1
        end
        return x[1]^2 + x[2] - 1
    end
    function ineq03(x::Vector, grad::Vector)
        if length(grad) > 0
            grad[1] = 2 * x[1]
            grad[2] = -1
        end
        return x[1]^2 - x[2] - 1
    end
    function eq01(x::Vector, grad::Vector)
        if length(grad) > 0
            grad[1] = 2
            grad[2] = 1
        end
        return 2 * x[1] + x[2] - 1
    end
    opt = Opt(:LD_SLSQP, 2)
    opt.lower_bounds = [0, -0.5]
    opt.upper_bounds = [1, 2]
    opt.xtol_rel = 1e-21
    opt.min_objective = rosenbrock
    opt.inequality_constraint = ineq01
    opt.inequality_constraint = ineq02
    opt.inequality_constraint = ineq03
    opt.equality_constraint = eq01
    (minf, minx, ret) = optimize(opt, [0.5, 0])
    println("got $minf at $minx with constraints (returned $ret)")
    @test minx[1] ≈ 0.4149 rtol = 1e-3
    @test minx[2] ≈ 0.1701 rtol = 1e-3
    remove_constraints!(opt)
    (minf, minx, ret) = optimize(opt, [0.5, 0])
    println("got $minf at $minx after removing constraints (returned $ret)")
    @test minx[1] ≈ 1 rtol = 1e-5
    @test minx[2] ≈ 1 rtol = 1e-5
    return
end

function test_tutorial()
    count = 0 # keep track of # function evaluations
    function myfunc(x::Vector, grad::Vector)
        if length(grad) > 0
            grad[1] = 0
            grad[2] = 0.5 / sqrt(x[2])
        end
        count::Int += 1
        println("f_$count($x)")
        return sqrt(x[2])
    end
    function myconstraint(x::Vector, grad::Vector, a, b)
        if length(grad) > 0
            grad[1] = 3a * (a * x[1] + b)^2
            grad[2] = -1
        end
        return (a * x[1] + b)^3 - x[2]
    end
    opt = Opt(:LD_MMA, 2)
    opt.lower_bounds = [-Inf, 0.0]
    opt.xtol_rel = 1e-4
    opt.min_objective = myfunc
    opt.inequality_constraint = (x, g) -> myconstraint(x, g, 2, 0)
    opt.inequality_constraint = (x, g) -> myconstraint(x, g, -1, 1)
    # test algorithm-parameter API
    opt.params["verbosity"] = 0
    opt.params["inner_maxeval"] = 10
    opt.params["dual_alg"] = NLopt.LD_MMA
    @test opt.params == Dict(
        "verbosity" => 0,
        "inner_maxeval" => 10,
        "dual_alg" => Int(NLopt.LD_MMA),
    )
    @test get(opt.params, "foobar", 3.14159) === 3.14159
    (minf, minx, ret) = optimize(opt, [1.234, 5.678])
    println("got $minf at $minx after $count iterations (returned $ret)")
    @test minx[1] ≈ 1 / 3 rtol = 1e-5
    @test minx[2] ≈ 8 / 27 rtol = 1e-5
    @test minf ≈ sqrt(8 / 27) rtol = 1e-5
    @test ret == :XTOL_REACHED
    @test opt.numevals == count
    return
end

# It's not obvious why this test returns FAILURE. If it breaks in future, look
# for something else.
function test_return_FAILURE_from_optimize()
    function objective_fn(x, grad)
        if length(grad) > 0
            grad[1] = -2 * (1 - x[1]) - 400 * x[1] * (x[2] - x[1]^2)
            grad[2] = 200 * (x[2] - x[1]^2)
        end
        return (1 - x[1])^2 + 100 * (x[2] - x[1]^2)^2
    end
    function eq_constraint_fn(h, x, J)
        if length(J) > 0
            J[1, 1] = 2x[1]
            J[2, 1] = 2x[2]
        end
        h[1] = x[1]^2 + x[2]^2 - 1.0
        return
    end
    opt = Opt(:AUGLAG, 2)
    opt.local_optimizer = Opt(:LD_LBFGS, 2)
    opt.min_objective = objective_fn
    equality_constraint!(opt, eq_constraint_fn, [1e-8])
    _, _, ret = optimize(opt, [0.5, 0.5])
    @test ret == :FAILURE
    return
end

function test_optimize!_bounds_error()
    opt = Opt(:AUGLAG, 2)
    @test_throws BoundsError optimize!(opt, Cdoulbe[])
    return
end

function test_property_names()
    opt = Opt(:AUGLAG, 2)
    for (key, value) in (
        :lower_bounds => [1, 2],
        :upper_bounds => [2, 3],
        :stopval => 0.5,
        :ftol_rel => 0.1,
        :ftol_abs => 0.2,
        :xtol_rel => 0.3,
        :xtol_abs => [0.4, 0.5],  # TODO
        :maxeval => 5,
        :maxtime => 60.0,
        :force_stop => 1,
        :population => 0x00000001,
        :vector_storage => 0x00000002,
    )
        @test key in propertynames(opt)
        f = getfield(NLopt, key)
        @test getproperty(opt, key) == f(opt)
        setproperty!(opt, key, value)
        @test f(opt) == value
    end
    # Other getters
    @test :initial_step in propertynames(opt)
    @test_throws(
        ErrorException(
            "Getting `initial_step` is unsupported. Use `initial_step(opt, x)` to access the initial step at a point `x`.",
        ),
        opt.initial_step,
    )
    @test :algorithm in propertynames(opt)
    @test opt.algorithm == algorithm(opt)
    @test :numevals in propertynames(opt)
    @test opt.numevals == NLopt.numevals(opt)
    @test :errmsg in propertynames(opt)
    @test opt.errmsg == NLopt.errmsg(opt)
    @test :params in propertynames(opt)
    @test opt.params == NLopt.OptParams(opt)
    @test_throws ErrorException("type Opt has no readable property foo") opt.foo
    return
end

function test_get_opt_params_default()
    opt = Opt(:AUGLAG, 2)
    @test get(opt.params, "abc", :default) == :default
    return
end

function test_srand()
    @test NLopt.srand(1234) === nothing
    @test NLopt.srand_time() === nothing
    return
end

function test_algorithm()
    opt = Opt(:LD_LBFGS, 2)
    @test algorithm(opt) == NLopt.LD_LBFGS
    return
end

function test_algorithm_enum()
    @test convert(Algorithm, NLopt.NLOPT_LD_LBFGS) == NLopt.LD_LBFGS
    @test convert(NLopt.nlopt_algorithm, NLopt.LD_LBFGS) == NLopt.NLOPT_LD_LBFGS
    return
end

function test_result_enum()
    @test convert(Result, NLopt.NLOPT_SUCCESS) == NLopt.SUCCESS
    @test convert(NLopt.nlopt_result, NLopt.SUCCESS) == NLopt.NLOPT_SUCCESS
    return
end

function test_result_arithmetic()
    @test !(NLopt.SUCCESS < 0)
    @test 0 < NLopt.SUCCESS
    @test NLopt.SUCCESS == :SUCCESS
    @test :SUCCESS == NLopt.SUCCESS
    return
end

function test_opt_argument_error()
    @test_throws ArgumentError Opt(:LD_LBFGS, -2)
    return
end

function test_show_opt()
    opt = Opt(:LD_LBFGS, 2)
    @test sprint(show, opt) == "Opt(LD_LBFGS, 2)"
    return
end

function test_chk()
    opt = Opt(:LD_LBFGS, 2)
    @test NLopt.chk(opt, NLopt.SUCCESS) === nothing
    @test NLopt.chk(opt, NLopt.ROUNDOFF_LIMITED) === nothing
    @test_throws ArgumentError NLopt.chk(opt, NLopt.INVALID_ARGS)
    @test_throws OutOfMemoryError NLopt.chk(opt, NLopt.OUT_OF_MEMORY)
    @test_throws(
        ErrorException("nlopt failure FAILURE"),
        NLopt.chk(opt, NLopt.FAILURE)
    )
    return
end

function test_algorithm_name()
    algorithm = NLopt.LD_LBFGS
    sol = "Limited-memory BFGS (L-BFGS) (local, derivative-based)"
    @test algorithm_name(algorithm) == sol
    @test algorithm_name(:LD_LBFGS) == sol
    @test algorithm_name(11) == sol
    opt = Opt(:LD_LBFGS, 2)
    @test algorithm_name(opt) == sol
    sprint(show, algorithm_name(:LD_LBFGS))
    @test sprint(show, MIME("text/plain"), NLopt.LD_LBFGS) ==
          "NLopt.LD_LBFGS: Limited-memory BFGS (L-BFGS) (local, derivative-based)"
    return
end

end  # module

TestCAPI.runtests()
