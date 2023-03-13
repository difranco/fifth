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

struct ParameterPopulation
	parameters :: AbstractMatrix
	fitnesses :: Vector{Function}
end

@inline topCalc(n) = Int(floor(sqrt(n)))

function adapt(p :: ParameterPopulation;
	             diversity = false, agg :: Function = sum)
	numSamples = size(p.parameters)[2]
	top = topCalc(numSamples)
	middle = div(numSamples, 3)

	if diversity
		fitnesses = copy(p.fitnesses)
		push!(fitnesses, (v) -> maximum(agg(v .⊻ p.parameters[:, 1:top], dims=1))) #make sure applied when parameters sorted
	else
		fitnesses = p.fitnesses
	end

	numFitnesses = length(fitnesses)

	makepointers() = collect(Int16, 1:numSamples)

	fitnessresults = zeros(Float16, numFitnesses, numSamples)
	
	for f in 1:numFitnesses, s in 1:numSamples
		pvec = p.parameters[:, s]
		try
			fitnessresults[f,s] = fitnesses[f](pvec)
		catch e
			# leave fitness zero
			@debug "Fitness $f failed with $e on sample $s with value " pvec
		end
	end

	ranks = fill(Int16(0), numFitnesses, numSamples)

	for f in 1:numFitnesses
		pointers = makepointers()
		sort!(pointers,
		  by = (pointer) -> fitnessresults[f, pointer],
		  rev = true)
		# pointers[i] now points to the parameter vector with the ith rank in fitness f
		pointerranks = map(t -> t[2], sort(reverse.(collect(enumerate(pointers)))))
		ranks[f, :] = pointerranks
	end

	pointers = makepointers()

	sort!(pointers,
		by = (pointer) -> agg(ranks[:, pointer]),
		rev = false)

	# fit top
	dist = unimodalDist(p.parameters[:, pointers[1:top]], 0.01)

	# replace bottom
	resamples = sampleBernoulli(dist, numSamples - middle + 1)
	p.parameters[:, pointers[middle : end]] = resamples
	unsortedparameters = copy(p.parameters)

	for (i, pointer) in enumerate(pointers)
		p.parameters[:, i] = unsortedparameters[:, pointer]
	end

	return p
end

end # module AdaptFit
