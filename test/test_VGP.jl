using Test
using AugmentedGaussianProcesses
using LinearAlgebra
using Statistics
const AGP = AugmentedGaussianProcesses
include("testingtools.jl")

nData = 100; nDim = 2
k = AGP.RBFKernel()
ν = 5.0

X = rand(nData,nDim)
y = Dict("Regression"=>norm.(eachrow(X)),"Classification"=>Int64.(sign.(norm.(eachrow(X)).-0.5)),"MultiClass"=>floor.(Int64,norm.(eachrow(X.*2))))
reg_likelihood = ["GaussianLikelihood","StudentTLikelihood","LaplaceLikelihood"]
class_likelihood = ["BayesianSVM","LogisticLikelihood"]
multiclass_likelihood = ["LogisticSoftMaxLikelihood","SoftMaxLikelihood"]
likelihood_types = [reg_likelihood,class_likelihood,multiclass_likelihood]
likelihood_names = ["Regression","Classification","MultiClass"]
# likelihood_names = ["Regression"]
# inferences = ["GibbsSampling"]#,"NumericalInference"]#,"GibbsSampling"]
inferences = ["AnalyticVI","GibbsSampling"]#,"NumericalInference"]#,"GibbsSampling"]
floattypes = [Float64]
@testset "VGP" begin
    for (likelihoods,l_names) in zip(likelihood_types,likelihood_names)
        @testset "$l_names" begin
            for l in likelihoods
                @testset "$(string(l))" begin
                    for inference in inferences
                        @testset "$(string(inference))" begin
                            if in(inference,methods_implemented_VGP[l])
                                for floattype in floattypes
                                    @test typeof(VGP(X,y[l_names],k,eval(Meta.parse(l*"("*addlargument(l)*")")),eval(Meta.parse(inference*"("*addiargument(false,inference)*")")))) <: VGP{eval(Meta.parse(l*"{"*string(floattype)*"}")),eval(Meta.parse(inference*"{"*string(floattype)*"}")),floattype,Vector{floattype}}
                                    model = VGP(X,y[l_names],k,eval(Meta.parse(l*"("*addlargument(l)*")")),eval(Meta.parse(inference*"("*addiargument(false,inference)*")")),Autotuning=true,verbose=3)
                                    @test train!(model,iterations=50)
                                    @test testconv(model,l_names,X,y[l_names])
                                end
                            else
                                @test_throws AssertionError VGP(X,y[l_names],k,eval(Meta.parse(l*"("*addlargument(l)*")")),eval(Meta.parse(inference*"()")))
                            end
                        end
                    end
                end
            end
        end
    end
end
