module AdaptFit
using Logging
using ..Fit

export ParameterPopulation, adapt, diversity

#= Follow up ideas:
#  cluster to get modes (similarity alignment)
#  BayesMix (AIXI) weight each cluster center distribution on data batch
#  Resample non-elites from weighted distribution
#  Diversity metaobjective of min difference from previous elite set implements
#   Quality Diversity
#  
=#

#!("./src/" in LOAD_PATH) ? push!(LOAD_PATH, "./src/")

@inline makepointers(numSamples) = collect(Int16, 1:numSamples)

# given pointers[i] points to the parameter vector with the ith rank in fitness f
# below we swap indices with ranks and sort by index and put ranks into ranks matrix
# should check to see if this is a noop on the corresponding permutation (cyclic?)
@inline sortedPointersToRanks(pointers) = map(t -> t[2], sort(reverse.(collect(enumerate(pointers)))))

struct ParameterPopulation
	parameters :: BitMatrix
	fitnesses :: Vector{Function}
	fitnessresults :: Matrix{Float16}
	rankpointersbyfitness :: Matrix{Int16}
	rankpointers :: Vector{Int16}
end

function ParameterPopulation(parameters :: BitMatrix, fitnesses :: Vector{Function};
	  pdiversity = false, rdiversity = false)
	numSamples = size(parameters)[2]
	top = topCalc(numSamples)

	numFitnesses = length(fitnesses) + sum([pdiversity, rdiversity])
	fitnessresults = zeros(Float16, numFitnesses, numSamples)
	rankpointersbyfitness = zeros(Int16, numFitnesses, numSamples)

	for (i, f) in enumerate(fitnesses)
		fitnesses[i] = (v :: BitVector, s :: Int) -> f(v)
	end

	if pdiversity
		@inline parameterdiff(v :: BitVector) = v .⊻ parameters[:, rankpointers[1:top]]
		parameterdiversity = (v :: BitVector, s :: Int) -> minimum(sum(parameterdiff(v), dims = 2))
		push!(fitnesses, parameterdiversity)
	end
	if rdiversity
		rpf = rankpointersbyfitness
		@inline fitrankdiff = (s :: Int) -> rpf[:, s] .- rpf[:, rankpointers[1:top]]
		rankdiversity = (v :: BitVector, s :: Int) -> minimum(sum(abs.(fitrankdiff(s)), dims = 2))
		push!(fitnesses, rankdiversity)
	end

	for f in 1:numFitnesses
		rankpointersbyfitness[f,:] = makepointers(numSamples)
	end
	rankpointers = makepointers(numSamples)

	ParameterPopulation(parameters, fitnesses, fitnessresults, rankpointersbyfitness, rankpointers)
end

@inline topCalc(n) = Int(ceil(sqrt(n)))

function adapt(p :: ParameterPopulation; agg :: Function = sum)
	numSamples = size(p.parameters)[2]
	numFitnesses = length(p.fitnesses)

	top = topCalc(numSamples)
	middle = div(numSamples, 3)

	for f in 1:numFitnesses, s in 1:numSamples
		pvec = p.parameters[:, s]
		try
			p.fitnessresults[f,s] = p.fitnesses[f](pvec, s)
		catch e
			p.fitnessresults[f,s] = 0
			@info "Fitness $f failed with $e on sample $s with value " pvec
		end
	end

	for f in 1:numFitnesses
		pointers = p.rankpointersbyfitness[f,:]
		sort!(pointers,
		  by = (pointer) -> p.fitnessresults[f, pointer],
		  rev = true)
	end

	pointers = p.rankpointers

	sort!(pointers,
		by = (pointer) -> agg(p.rankpointersbyfitness[:, pointer]),
		rev = false)

	# fit top
	dist = unimodalDist(p.parameters[:, pointers[1:top]], 0.01)

	# replace bottom
	resamples = sampleBernoulli(dist, numSamples - middle + 1)
	p.parameters[:, pointers[middle : end]] = resamples

	return p
end

end # module AdaptFit
