"""
Class for variational Gaussian Processes models (non-sparse)

```julia
 VGP(X::AbstractArray{T1,N1},y::AbstractArray{T2,N2},
     kernel::Union{Kernel,AbstractVector{<:Kernel}},
     likelihood::LikelihoodType,inference::InferenceType;
     verbose::Integer=0,Autotuning::Bool=true,
     atfrequency::Integer=1,IndependentPriors::Bool=true,
     ArrayType::UnionAll=Vector)
```

Argument list :

**Mandatory arguments**

 - `X` : input features, should be a matrix N×D where N is the number of observation and D the number of dimension
 - `y` : input labels, can be either a vector of labels for multiclass and single output or a matrix for multi-outputs (note that only one likelihood can be applied)
 - `kernel` : covariance function, can be either a single kernel or a collection of kernels for multiclass and multi-outputs models
 - `likelihood` : likelihood of the model, currently implemented : Gaussian, Bernoulli (with logistic link), Multiclass (softmax or logistic-softmax) see [`Likelihood Types`](@ref likelihood_user)
 - `inference` : inference for the model, can be analytic, numerical or by sampling, check the model documentation to know what is available for your likelihood see the [`Compatibility Table`](@ref compat_table)

**Keyword arguments**

 - `verbose` : How much does the model print (0:nothing, 1:very basic, 2:medium, 3:everything)
 - `Autotuning` : Flag for optimizing hyperparameters
 - `atfrequency` : Choose how many variational parameters iterations are between hyperparameters optimization
 - `IndependentPriors` : Flag for setting independent or shared parameters among latent GPs
 - `ArrayType` : Option for using different type of array for storage (allow for GPU usage)
"""
mutable struct VGP{L<:Likelihood,I<:Inference,T<:Real,V<:AbstractVector{T}} <: AbstractGP{L,I,T,V}
    X::Matrix{T} #Feature vectors
    y::LatentArray #Output (-1,1 for classification, real for regression, matrix for multiclass)
    nSample::Int64 # Number of data points
    nDim::Int64 # Number of covariates per data point
    nFeature::Int64 # Number of features of the GP (equal to number of points)
    nLatent::Int64 # Number pf latent GPs
    IndependentPriors::Bool # Use of separate priors for each latent GP
    nPrior::Int64 # Equal to 1 or nLatent given IndependentPriors
    μ::LatentArray{V}
    Σ::LatentArray{Symmetric{T,Matrix{T}}}
    η₁::LatentArray{V}
    η₂::LatentArray{Symmetric{T,Matrix{T}}}
    Knn::LatentArray{Symmetric{T,Matrix{T}}}
    invKnn::LatentArray{Symmetric{T,Matrix{T}}}
    kernel::LatentArray{Kernel{T}}
    likelihood::Likelihood{T}
    inference::Inference{T}
    verbose::Int64 #Level of printing information
    Autotuning::Bool
    atfrequency::Int64
    Trained::Bool
end


function VGP(X::AbstractArray{T1,N1},y::AbstractArray{T2,N2},kernel::Union{Kernel,AbstractVector{<:Kernel}},
            likelihood::LikelihoodType,inference::InferenceType;
            verbose::Integer=0,Autotuning::Bool=true,atfrequency::Integer=1,
            IndependentPriors::Bool=true,ArrayType::UnionAll=Vector) where {T1<:Real,T2,N1,N2,LikelihoodType<:Likelihood,InferenceType<:Inference}

            X,y,nLatent,likelihood = check_data!(X,y,likelihood)
            @assert check_implementation(:VGP,likelihood,inference) "The $likelihood is not compatible or implemented with the $inference"

            nPrior = IndependentPriors ? nLatent : 1
            nFeature = nSample = size(X,1); nDim = size(X,2);
            kernel = ArrayType([deepcopy(kernel) for _ in 1:nPrior])

            μ = LatentArray([zeros(T1,nFeature) for _ in 1:nLatent]); η₁ = deepcopy(μ)
            Σ = LatentArray([Symmetric(Matrix(Diagonal(one(T1)*I,nFeature))) for _ in 1:nLatent]);
            η₂ = -0.5*inv.(Σ);
            Knn = LatentArray([deepcopy(Σ[1]) for _ in 1:nPrior]);
            invKnn = copy(Knn)

            likelihood = init_likelihood(likelihood,inference,nLatent,nSample)
            inference = init_inference(inference,nLatent,nSample,nSample,nSample)

            VGP{LikelihoodType,InferenceType,T1,ArrayType{T1}}(X,y,
                    nFeature, nDim, nFeature, nLatent,
                    IndependentPriors,nPrior,μ,Σ,η₁,η₂,
                    Knn,invKnn,kernel,likelihood,inference,
                    verbose,Autotuning,atfrequency,false)
end

function Base.show(io::IO,model::VGP{<:Likelihood,<:Inference,T}) where T
    print(io,"Variational Gaussian Process with a $(model.likelihood) infered by $(model.inference) ")
end
