"""
**Bayesian SVM**

The [Bayesian SVM](https://arxiv.org/abs/1707.05532) is a Bayesian interpretation of the classical SVM.
``p(y|f) \\propto \\exp\\left(2\\max(1-yf,0)\\right)``

```julia
BayesianSVM()
```
---
For the analytic version of the likelihood, it is augmented via:
```math
p(y|f,\\omega) = \\frac{1}{\\sqrt{2\\pi\\omega}}\\exp\\left(-\\frac{1}{2}\\frac{(1+\\omega-yf)^2}{\\omega}\\right)
```
where ``\\omega\\sim 1_{[0,\\infty]}`` has an improper prior (his posterior is however has a valid distribution (Generalized Inverse Gaussian)). For reference [see this paper](http://ecmlpkdd2017.ijs.si/papers/paperID502.pdf)
"""
struct BayesianSVM{T<:Real} <: ClassificationLikelihood{T}
    ω::AbstractVector{AbstractVector{T}}
    θ::AbstractVector{AbstractVector{T}}
    function BayesianSVM{T}() where {T<:Real}
        new{T}()
    end
    function BayesianSVM{T}(ω::AbstractVector{<:AbstractVector{<:Real}},θ::AbstractVector{<:AbstractVector{<:Real}}) where {T<:Real}
        new{T}(ω,θ)
    end
end

function BayesianSVM()
    BayesianSVM{Float64}()
end

isaugmented(::BayesianSVM{T}) where T = true

function init_likelihood(likelihood::BayesianSVM{T},inference::Inference{T},nLatent::Integer,nSamplesUsed) where T
    BayesianSVM{T}([abs.(rand(T,nSamplesUsed)) for _ in 1:nLatent],[zeros(T,nSamplesUsed) for _ in 1:nLatent])
end
function pdf(l::BayesianSVM,y::Real,f::Real)
    svmlikelihood(y*f)
end

function Base.show(io::IO,model::BayesianSVM{T}) where T
    print(io,"Bayesian SVM")
end

"""Return likelihood equivalent to SVM hinge loss"""
function svmlikelihood(f::Real)
    pos = svmpseudolikelihood(f)
    return pos./(pos.+svmpseudolikelihood(-f))
end

"""Return the pseudo likelihood of the SVM hinge loss"""
function svmpseudolikelihood(f::Real)
    return exp(-2.0*max.(1.0-f,0))
end


function compute_proba(l::BayesianSVM{T},μ::Vector{T},σ²::Vector{T}) where {T<:Real}
    N = length(μ)
    pred = zeros(T,N)
    for i in 1:N
        if σ²[i] <= 0.0
            pred[i] = svmlikelihood(μ[i])
        else
            pred[i] =  expectation(svmlikelihood,Normal(μ[i],sqrt(σ²[i])))
        end
    end
    return pred
end

###############################################################################


function local_updates!(model::VGP{BayesianSVM{T},<:AnalyticVI}) where {T<:Real}
    model.likelihood.ω .= broadcast((μ,Σ,y)->abs2.(one(T) .- y.*μ) + Σ ,model.μ,diag.(model.Σ),model.y)
    model.likelihood.θ .= broadcast(b->one(T)./sqrt.(b),model.likelihood.ω)
end

function local_updates!(model::SVGP{BayesianSVM{T},<:AnalyticVI}) where {T<:Real}
    model.likelihood.ω .= broadcast((κ,μ,Σ,y,K̃)->abs2.(one(T) .- y[model.inference.MBIndices].*(κ*μ)) + opt_diag(κ*Σ,κ) + K̃,model.κ,model.μ,model.Σ,model.y,model.K̃)
    model.likelihood.θ .= broadcast(b->one(T)./sqrt.(b),model.likelihood.ω)
end

""" Return the gradient of the expectation for latent GP `index` """
function expec_μ(model::VGP{BayesianSVM{T}},index::Integer) where {T<:Real}
    return model.y[index].*(model.likelihood.θ[index] .+ one(T))
end

function ∇μ(model::VGP{BayesianSVM{T}}) where {T<:Real}
    return broadcast((y,θ)->y.*(θ.+one(T)),model.y,model.likelihood.θ)
end

""" Return the gradient of the expectation for latent GP `index` """
function expec_μ(model::SVGP{BayesianSVM{T}},index::Integer) where {T<:Real}
    return model.y[index][model.inference.MBIndices].*(model.likelihood.θ[index].+one(T))
end

function ∇μ(model::SVGP{BayesianSVM{T}}) where {T<:Real}
    return broadcast((y,θ)->y[model.inference.MBIndices].*(θ.+one(T)),model.y,model.likelihood.θ)
end

function expec_Σ(model::AbstractGP{BayesianSVM{T}},index::Integer) where {T<:Real}
    return 0.5*model.likelihood.θ[index]
end

function ∇Σ(model::AbstractGP{BayesianSVM{T}}) where {T<:Real}
    return model.likelihood.θ
end

function ELBO(model::AbstractGP{<:BayesianSVM})
    return expecLogLikelihood(model) - GaussianKL(model) - GIGEntropy(model)
end

function expecLogLikelihood(model::VGP{BayesianSVM{T},AnalyticVI{T}}) where {T<:Real}
    tot = -model.nLatent*(0.5*model.nSample*logtwo)
    tot += sum(broadcast((μ,y,θ,Σ)->(sum(μ.*y)-0.5*dot(θ,Σ+abs2.(one(T).-y.*μ))),
                        model.μ,model.y,model.likelihood.θ,diag.(model.Σ)))
    return tot
end

function expecLogLikelihood(model::SVGP{BayesianSVM{T},AnalyticVI{T}}) where {T<:Real}
    tot = -model.nLatent*(0.5*model.nSample*logtwo)
    tot += sum(broadcast((κμ,y,θ,κΣκ,K̃)->(sum(κμ.*y[model.inference.MBIndices])-0.5*dot(θ,K̃+κΣκ+abs2.(one(T).-y[model.inference.MBIndices].*κμ))),
                        model.κ.*model.μ,model.y,model.likelihood.θ,opt_diag.(model.κ.*model.Σ,model.κ),model.K̃))
    return model.inference.ρ*tot
end
