include("tutorial.jl")
include("fix133.jl")
include("MPB_wrapper.jl")
include("MOI_wrapper.jl")

using NLopt
using Test

@testset "Fix #163" begin
    opt = Opt(:LN_COBYLA, 2)
    opt.min_objective = (x, g) -> sum(x.^2)
    inequality_constraint!(opt, 2, (result, x, g) -> (result .= 1 .- x))
    (minf, minx, ret) = optimize(opt, [2.0, 2.0])
    @test minx ≈ [1.0, 1.0]
end
