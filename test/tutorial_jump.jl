# Copyright (c) 2013: Steven G. Johnson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

using JuMP, NLopt, Test

model = Model(NLopt.Optimizer)
set_optimizer_attribute(model, "algorithm", :LD_MMA)

a1 = 2
b1 = 0
a2 = -1
b2 = 1

@variable(model, x1)
@variable(model, x2 >= 0)

@NLobjective(model, Min, sqrt(x2))
@NLconstraint(model, x2 >= (a1*x1+b1)^3)
@NLconstraint(model, x2 >= (a2*x1+b2)^3)

set_start_value(x1, 1.234)
set_start_value(x2, 5.678)

optimize!(model)

println("got ", objective_value(model), " at ", [value(x1), value(x2)])

@test_approx_eq_eps value(x1) 1/3 1e-5
@test_approx_eq_eps value(x2) 8/27 1e-5
@test_approx_eq_eps objective_value(m) sqrt(8/27) 1e-5
@test termination_status(model) == MOI.OPTIMAL
