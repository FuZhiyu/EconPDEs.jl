using EconPDEs, LeastSquaresOptim

struct BoltonChenWangModel
  r::Float64
  δ::Float64
  A::Float64
  σ::Float64
  θ::Float64
  λ::Float64
  l::Float64
  γ::Float64
  ϕ::Float64
end

function BoltonChenWangModel(r = 0.06, δ = 0.10, A = 0.18, σ = 0.09, θ = 1.5, λ = 0.01, l = 0.9, γ = 0.06, ϕ = 0.01)
  BoltonChenWang(r, δ, A, σ, θ, λ, l , γ, ϕ)
end

function initialize_state(m::BoltonChenWangModel; wn = 100)
  OrderedDict(:w => collect(range(0.0, stop = 0.3, length = wn)))
end

function initialize_y(m::BoltonChenWangModel, state)
    OrderedDict(:v =>  1.0 .+ state[:w])
end

function (m::BoltonChenWangModel)(state, y)
  r = m.r; δ = m.δ; A = m.A; σ = m.σ; θ = m.θ; λ = m.λ; l = m.l; γ = m.γ; ϕ = m.ϕ
  w = state.w
  v, vw, vww = y.v, y.vw, y.vww
  i = 1 / θ * (v / vw - w - 1)
  vt = (i - δ) * (v - vw * w) + ((r - λ) * w + A - i - θ * i^2 / 2) * vw + σ^2 / 2 * vww - r * v
  μw = (r - λ) * w + A - i - θ * i^2 / 2 - (i - δ) * w
  return (vt,), (μw, ), (v = v, vw = vw, vww = vww, w = w)
end

m = BoltonChenWangModel()
state = initialize_state(m)
y0 = initialize_y(m, state)



# This function iterates on the boundary conditions on the derivative of the value function until the solution satisfies the conditions given in Bolton Chen Wang (2009).
function f(m, x, state, y0)
  y, result, distance = pdesolve(m, state, y0; bc = OrderedDict(:vw => (x[1], x[2])))
  y0[:v] = y[:v]
  u1, u2, w = result[:v], result[:vw], result[:w]
  out = zeros(4)
  mi = argmin(abs.(1 + m.γ .- u2))
  out[1] = u2[mi] - 1 - m.γ
  out[2] =  u1[mi] - m.ϕ - (1 + m.γ) * w[mi] - u1[1]
  wi = argmin(abs.(1 .-u2))
  out[3] = u2[wi] - 1
  i = 1 / m.θ * (u1[wi] - w[wi] - 1)
  out[4] = m.r * u1[wi] - (i - m.δ) * (u1[wi] - w[wi]) - ((m.r - m.λ) * w[wi] + m.A - i - m.θ * i^2 / 2)
  return out
end
newsol = optimize(x -> f(m, x, state, y0), [1.0,  1.0], Dogleg())
y, result, distance = pdesolve(m, state, y0; bc = OrderedDict(:vw => (newsol.minimizer[1],newsol.minimizer[2])))


