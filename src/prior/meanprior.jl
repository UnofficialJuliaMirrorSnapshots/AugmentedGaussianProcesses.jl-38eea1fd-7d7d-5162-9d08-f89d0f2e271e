abstract type MeanPrior{T} end

import Base: +, -, *, convert

include("constantmean.jl")
include("zeromean.jl")
include("empiricalmean.jl")
