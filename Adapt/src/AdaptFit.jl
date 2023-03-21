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

function ParameterPopulation(parameters, fitnesses; pdiversity = false, rdiversity = false)
	numSamples = size(parameters)[2]
	top = topCalc(numSamples)

	if pdiversity
		push!(fitnesses, (v) -> maximum(sum(v .⊻ parameters[:, rankpointers[1:top]], dims=1)))
	end
	if rdiversity
		push!(fitnesses, (v) -> maximum(sum(abs.(v .- rankpointers[[1:top]]))))
	end

	numFitnesses = length(fitnesses)

	fitnessresults = zeros(Float16, numFitnesses, numSamples)
	rankpointersbyfitness = zeros(Int16, numFitnesses, numSamples)

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

	for f in 1:numFitnesses, r in p.rankpointers
		pvec = p.parameters[:, r]
		try
			p.fitnessresults[f,r] = p.fitnesses[f](pvec)
		catch e
			p.fitnessresults[f,r] = 0
			@debug "Fitness $f failed with $e on sample ranked $r with value " pvec
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
