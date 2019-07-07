"""
**AnalyticVI**

Variational Inference solver for conjugate or conditionally conjugate likelihoods (non-gaussian are made conjugate via augmentation)
All data is used at each iteration (use AnalyticSVI for Stochastic updates)

```julia
AnalyticVI(;ϵ::T=1e-5)
```
**Keywords arguments**

    - `ϵ::T` : convergence criteria
"""
mutable struct AnalyticVI{T<:Real} <: Inference{T}
    ϵ::T #Convergence criteria
    nIter::Integer #Number of steps performed
    optimizer_η₁::LatentArray{Optimizer} #Learning rate for stochastic updates
    optimizer_η₂::LatentArray{Optimizer} #Learning rate for stochastic updates
    Stochastic::Bool #Use of mini-batches
    nSamples::Int64
    nSamplesUsed::Int64 #Size of mini-batches
    MBIndices::Vector{Int64} #Indices of the minibatch
    ρ::T #Stochastic Coefficient
    HyperParametersUpdated::Bool #To know if the inverse kernel matrix must updated
    ∇η₁::LatentArray{Vector{T}}
    ∇η₂::LatentArray{Matrix{T}} #Stored as a matrix since symmetric sums do not help for the moment WARNING
    function AnalyticVI{T}(ϵ::T,nIter::Integer,optimizer_η₁::AbstractVector{<:Optimizer},optimizer_η₂::AbstractVector{<:Optimizer},Stochastic::Bool,nSamples::Integer,nSamplesUsed::Integer,MBIndices::AbstractVector,ρ::T,flag::Bool) where T
        return new{T}(ϵ,nIter,optimizer_η₁,optimizer_η₂,Stochastic,nSamples,nSamplesUsed,MBIndices,ρ,flag)
    end
    function AnalyticVI{T}(ϵ::T,nIter::Integer,optimizer_η₁::AbstractVector{<:Optimizer},optimizer_η₂::AbstractVector{<:Optimizer},Stochastic::Bool,nSamples::Integer,nSamplesUsed::Integer,MBIndices::AbstractVector,ρ::T,flag::Bool,∇η₁::AbstractVector{<:AbstractVector},
    ∇η₂::AbstractVector{<:AbstractMatrix}) where T
        return new{T}(ϵ,nIter,optimizer_η₁,optimizer_η₂,Stochastic,nSamples,nSamplesUsed,MBIndices,ρ,flag,∇η₁,∇η₂)
    end
end


function AnalyticVI(;ϵ::T=1e-5) where {T<:Real}
    AnalyticVI{Float64}(ϵ,0,[VanillaGradDescent(η=1.0)],[VanillaGradDescent(η=1.0)],false,1,1,[1],1.0,true)
end

"""
**AnalyticSVI**
Stochastic Variational Inference solver for conjugate or conditionally conjugate likelihoods (non-gaussian are made conjugate via augmentation)

```julia
AnalyticSVI(nMinibatch::Integer;ϵ::T=1e-5,optimizer::Optimizer=InverseDecay())
```
    - `nMinibatch::Integer` : Number of samples per mini-batches

**Keywords arguments**

    - `ϵ::T` : convergence criteria
    - `optimizer::Optimizer` : Optimizer used for the variational updates. Should be an Optimizer object from the [GradDescent.jl](https://github.com/jacobcvt12/GradDescent.jl) package. Default is `InverseDecay()` (ρ=(τ+iter)^-κ)
"""
function AnalyticSVI(nMinibatch::Integer;ϵ::T=1e-5,optimizer::Optimizer=InverseDecay()) where {T<:Real}
    AnalyticVI{T}(ϵ,0,[optimizer],[optimizer],true,1,nMinibatch,1:nMinibatch,1.0,true)
end

function Base.show(io::IO,inference::AnalyticVI{T}) where T
    print(io,"Analytic$(inference.Stochastic ? " Stochastic" : "") Variational Inference")
end


"""Initialize the final version of the inference object"""
function init_inference(inference::AnalyticVI{T},nLatent::Integer,nFeatures::Integer,nSamples::Integer,nSamplesUsed::Integer) where {T<:Real}
    inference.nSamples = nSamples
    inference.nSamplesUsed = nSamplesUsed
    inference.MBIndices = 1:nSamplesUsed
    inference.ρ = nSamples/nSamplesUsed
    inference.optimizer_η₁ = [copy(inference.optimizer_η₁[1]) for _ in 1:nLatent]
    inference.optimizer_η₂ = [copy(inference.optimizer_η₂[1]) for _ in 1:nLatent]
    inference.∇η₁ = [zeros(T,nFeatures) for _ in 1:nLatent];
    inference.∇η₂ = [Matrix(Diagonal(ones(T,nFeatures))) for _ in 1:nLatent]
    return inference
end

"""Generic method for variational updates using analytical formulas"""
function variational_updates!(model::AbstractGP{L,AnalyticVI{T}}) where {L<:Likelihood,T}
    local_updates!(model)
    natural_gradient!(model)
    global_update!(model)
end

"""Coordinate ascent updates on the natural parameters"""
function natural_gradient!(model::VGP{L,AnalyticVI{T}}) where {T<:Real,L<:Likelihood{T}}
    model.η₁ .= ∇μ(model) .+ model.invKnn.*model.μ₀
    model.η₂ .= -0.5*Symmetric.(Diagonal{T}.(∇Σ(model)).+model.invKnn)
end

"""Computation of the natural gradient for the natural parameters"""
function natural_gradient!(model::SVGP{L,AnalyticVI{T}}) where {T<:Real,L<:Likelihood{T}}
    map!(∇η₁,model.inference.∇η₁,∇μ(model),fill(model.inference.ρ,model.nLatent),model.κ,model.invKmm,model.μ₀,model.η₁)
    map!(∇η₂,model.inference.∇η₂,∇Σ(model),fill(model.inference.ρ,model.nLatent),model.κ,model.invKmm,model.η₂)
end

function ∇η₁(∇μ::AbstractVector{T},ρ::Real,κ::AbstractMatrix{T},invKmm::Symmetric{T,Matrix{T}},μ₀::PriorMean,η₁::AbstractVector{T}) where {T <: Real}
    transpose(κ)*(ρ*∇μ) + invKmm*μ₀ - η₁
end

function ∇η₂(θ::AbstractVector{T},ρ::Real,κ::AbstractMatrix{<:Real},invKmm::Symmetric{T,Matrix{T}},η₂::Symmetric{T,Matrix{T}}) where {T<:Real}
    -0.5*(ρκdiagθκ(ρ,κ,θ)+invKmm) - η₂
end

"""Conversion from natural to standard distribution parameters"""
function global_update!(model::VGP{L,AnalyticVI{T}}) where {L<:Likelihood,T}
    model.Σ .= -0.5.*inv.(model.η₂)
    model.μ .= model.Σ.*model.η₁
end

"""Update of the natural parameters and conversion from natural to standard distribution parameters"""
function global_update!(model::SVGP{L,AnalyticVI{T}}) where {L<:Likelihood,T}
    if model.inference.Stochastic
        model.η₁ .= model.η₁ .+ GradDescent.update.(model.inference.optimizer_η₁,model.inference.∇η₁)
        model.η₂ .= Symmetric.(model.η₂ .+ GradDescent.update.(model.inference.optimizer_η₂,model.inference.∇η₂))
    else
        model.η₁ .+= model.inference.∇η₁
        model.η₂ .= Symmetric.(model.inference.∇η₂ .+ model.η₂)
    end
    model.Σ .= -0.5.*inv.(model.η₂)
    model.μ .= model.Σ.*model.η₁
end
