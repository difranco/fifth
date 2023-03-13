using Test

using Logging
debuglogger = ConsoleLogger(stderr, Logging.Debug)
global_logger(debuglogger)

using RandomNumbers.Xorshifts
rng = Xoshiro128Plus(0xABADBABE)
import Random.bitrand, Random.shuffle

using Adapt.Fit:unimodalDist
using Adapt.AdaptFit:ParameterPopulation,adapt

dimension = 16
numSamples = 108

# topCalc = (n) -> max(Int(floor(n/8)), 3)
# uniform = ones{Float16}(dimension, 1) ./ 2
# popdistinit = parameters[:, shuffle(1:numSamples)[1:topCalc(numSamples)]]

ubytefitness = (x) -> sum(Array{UInt32}(reinterpret(UInt8, x)))
uwordfitness = (x) -> sum(Array{UInt32}(reinterpret(UInt16, x)))

bytefitness = (x) -> sum(Array{Int32}(reinterpret(Int8, x)))
wordfitness = (x) -> sum(Array{Int32}(reinterpret(Int16, x)))

matchcriterion = BitVector(rand(rng, Bool, dimension))
bitmatchfitness = (x) -> length(criterion) - sum(x .⊻ matchcriterion)

function testWordFit(fitnesses)
	parameters = BitMatrix(rand(rng, Bool, dimension, numSamples))
	p = ParameterPopulation(parameters, fitnesses)

	top10 = p.parameters[1:10]
	lasttop10 = top10
	for i in 1:1000
		p = adapt(p, diversity = true)
		if i % 5 != 0 continue end
		top10 = p.parameters[1:10]
		diff = lasttop10 .⊻ top10
		lasttop10 = copy(top10)
		@info "Iteration $i"
		if i < 888 continue end
		@info "Change count: $(sum(diff))"
		topfitness = sum(map((f) -> f(p.parameters[:, 1]), fitnesses))
		#@info "Fitness" fitnessresults
		#@info "Ranks" ranks
		@info "Top fitness: $topfitness"
	end

	endparams = sort(collect(enumerate(
		eachcol(p.parameters))), by = (r) -> sum(map(f -> f(r[2]), fitnesses)))

	@info "End top 20 " endparams[1:20]
end

# @info "End sample discrepancy: $(sum(abs.(unimodalDist(p.parameters) - criterion)))"

@testset "easy: unsigned words" begin
	fitnesses = [ubytefitness, uwordfitness]
	testWordFit(fitnesses)
	@test true # not the real way to do result reporting but works for now
end

@testset "harder: signed words" begin
	fitnesses = [bytefitness, wordfitness]
	testWordFit(fitnesses)
	@test true # not the real way to do result reporting but works for now
end
