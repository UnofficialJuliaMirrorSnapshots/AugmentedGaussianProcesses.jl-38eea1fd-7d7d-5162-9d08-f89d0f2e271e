"""

General Framework for the data augmented Gaussian Processes

"""
module AugmentedGaussianProcesses

export AbstractGP, GP, VGP, SVGP
export Likelihood,  RegressionLikelihood, ClassificationLikelihood, MultiClassLikelihood
export GaussianLikelihood, StudentTLikelihood, LaplaceLikelihood
export LogisticLikelihood, BayesianSVM
export SoftMaxLikelihood, LogisticSoftMaxLikelihood
export PoissonLikelihood
export Inference, Analytic, AnalyticVI, AnalyticSVI, GibbsSampling, MCMCIntegrationVI, MCMCIntegrationSVI, QuadratureVI, QuadratureSVI
export NumericalVI, NumericalSVI
export ALRSVI, InverseDecay

#Deprecated
export BatchGPRegression, SparseGPRegression, MultiClass, SparseMultiClass, BatchBSVM, SparseBSVM, BatchXGPC, SparseXGPC, BatchStudentT, SparseStudentT


#Useful functions and module
include("kernels/KernelModule.jl")
include("kmeans/KMeansModule.jl")
include("functions/PGSampler.jl")
#include("functions/PerturbativeCorrection.jl")
# include("functions/GPAnalysisTools.jl")
# include("functions/IO_model.jl")
#Custom modules
using .KernelModule
using .KMeansModule
using .PGSampler
# using .PerturbativeCorrection
# using .GPAnalysisTools
# using .IO_model
#General modules
# using MLKernels
using GradDescent
import GradDescent: update
using DataFrames
using Distributions
using LinearAlgebra
using StatsBase
using StatsFuns
using SpecialFunctions
using Dates
using Expectations
using Random
import Base: convert, show, copy
#Exported models
export KMeansModule
#Useful functions
export train!
export predict_f, predict_y, proba_y
# export getLog, getMultiClassLog
export Kernel,  Matern3_2Kernel, Matern5_2Kernel, RBFKernel, LaplaceKernel, SigmoidKernel, PolynomialKernel, ARDKernel
export kerneldiagmatrix, kerneldiagmatrix!, kernelmatrix, kernelmatrix!
export fstar, multiclasspredictproba, multiclasspredictprobamcmc, multiclasspredict, ELBO
export setvalue!,getvalue,setfixed!,setfree!,getvariance,getlengthscales,setoptimizer!
export opt_diag, opt_trace
export rand
export KMeansInducingPoints

# Main classes
abstract type Inference{T<:Real} end
abstract type Likelihood{T<:Real}  end

const LatentArray = Vector #For future optimization : How collection of latent GPs are stored
include("prior/meanprior.jl")

include("models/AbstractGP.jl")
include("models/GP.jl")
include("models/VGP.jl")
include("models/SVGP.jl")

include("inference/inference.jl")
include("likelihood/likelihood.jl")

include("functions/utils.jl")
include("functions/init.jl")
include("functions/KLdivergences.jl")
# include("functions/plotting.jl")
#Deprecated constructors
include("deprecated.jl")

#Training Functions
include("training.jl")
include("autotuning.jl")
include("predictions.jl")
end #End Module
