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
numSamples = 25 # 108

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
	p = ParameterPopulation(parameters, fitnesses, pdiversity = true, rdiversity = true)

	top10 = p.parameters[:, p.rankpointers[1:10]]
	lasttop10 = top10
	epochnochangecount = 0

	for i in 1:1000
		p = adapt(p)
		top10 = p.parameters[:, p.rankpointers[1:10]]
		diff = lasttop10 .⊻ top10
		lasttop10 = copy(top10)
		changecount = sum(diff)
		if changecount == 0 epochnochangecount += 1 end

		function printStatus()
			@info "Iteration $i"
			@info "Change count: $(changecount)"
			topfitness = sum(p.fitnessresults[:, p.rankpointers[1]])
			@info "Top fitness: $topfitness"
		end

		if epochnochangecount > 4
			printStatus()
			break
		end

		if i % 5 == 0
			printStatus()
			continue
		end
	end

	# @info "End top 20 " p.parameters[:, p.rankpointers[1:20]]
	@info p
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
