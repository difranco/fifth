module Fit

using Clustering
import StatsBase: sample, Weights
using Distributions

export findClustering, sample, sampleWeights, unimodalDist, sampleBernoulli

@inline score(a, b) = vmeasure(a, b)

function tryNewClustering(k :: Int, oldClustering :: KmeansResult, data :: BitMatrix)
	(dim, oldK) = size(oldClustering.centers)
	if k == oldK
		return oldClustering
	end
	c = copy(oldClustering.centers)

	if k < oldK
		c = c[:, 1:k]
	elseif k > oldK
		c = hcat(c, rand(dim, k - oldK))
	end

	return kmeans!(data, c, maxiter = 32)
end

function findClustering(data :: BitMatrix, initialGuess :: Union{KmeansResult,Nothing} = nothing)
	(dim, len) = size(data)
	initialK = 1
	initialGuess = initialGuess /= nothing ? initialGuess :
	 kmeans(data, initialK, maxiter = 64, display = :iter)

	bestGuess = initialGuess
	bestGuessScore = score(initialGuess, initialGuess)

	for k in initialK : Int(floor(1.5 * sqrt(len)))
		newGuess = tryNewClustering(k, bestGuess, data)
		newGuessScore = score(newGuess, bestGuess)

		if(newGuessScore > bestGuessScore)
			bestGuess = newGuess
			bestGuessScore = newGuessScore
		end
	end

	return bestGuess
end

function sampleWeights(c :: KmeansResult, numInSamples = 16)
	idxs = collect(1:size(c.centers)[2])
	points = sum(c.counts)
	cols = sample(idxs, Weights(c.counts ./ points), numInSamples)
	len = length(cols)
	return sum(c.centers[:, cols], dims = 2) ./ len
end

	function sample(c :: KmeansResult, numInSamples = 16, numOutSamples = 1)
		weights = sampleWeights(c, numInSamples)
		out = BitMatrix(undef, length(weights), numOutSamples)
		for i in eachindex(weights)
			for j in 1:numOutSamples
				out[i, j] = rand(Bernoulli(weights[i]))
			end
		end
		return out
	end

@inline function bound(x, low, high)
	return min(max(x, low), high)
end

function unimodalDist(data :: BitMatrix, smooth = 0)
	numrows = size(data)[2]
	rowcounts = sum(data, dims = 2)
	probabilities = bound.(Float16.(rowcounts) ./ numrows, smooth, 1 - smooth)
	return probabilities
end

import Distributions.Bernoulli

function sampleBernoulli(p :: AbstractMatrix, numSamples = 1)
	out = BitMatrix(undef, size(p)[1], numSamples)
	for i in 1:size(p)[1]
		for j in 1:numSamples
			out[i, j] = rand(Bernoulli(p[i]))
		end
	end
	return out
end

function select!(array::Array, left::Int, right::Int, k::Int)
	"""
	Partially sort the elements between left and right in ascending order,
	such that for some value k, where left ≤ k ≤ right, the kth element
	in the list will contain the (k − left + 1)th smallest value,
	and all elements at indices < k are ≤ all elements at indices ≥ k.
	"""
	while right > left
		# Use select recursively to sample a smaller set of size s
		# the arbitrary constants 600 and 0.5 are used in the original
		# version to minimize execution time.
		if right - left > 600
			n = right - left + 1
			i = k - left + 1
			z = ln(n)
			s = 0.5 × exp(2 × z/3)
			sd = 0.5 × sqrt(z × s × (n - s)/n) × sign(i - n/2)
			newLeft = max(left, k - i × s/n + sd)
			newRight = min(right, k + (n - i) × s/n + sd)
			select!(array, newLeft, newRight, k)
		end
		# partition the elements between left and right around t
		t = array[k]
		i = left
		j = right
		# swap array[left] and array[k]
		array[left], array[k] = array[k], array[left]
		if array[right] > t
			# swap array[right] and array[left]
			array[left], array[right] = array[right], array[left]
		end
		while i < j
			# swap array[i] and array[j]
			array[i], array[j] = array[j], array[i]
			i = i + 1
			j = j - 1
			while array[i] < t
				i = i + 1
			end
			while array[j] > t
				j = j - 1
			end
		end
		if array[left] == t
			# swap array[left] and array[j]
			array[left], array[j] = array[j], array[left]
		else
			j = j + 1
			# swap array[j] and array[right]
			array[right], array[j] = array[j], array[right]
		end
		# Adjust left and right towards the boundaries of the subset
		# containing the (k − left + 1)th smallest element.
		if j ≤ k
			left = j + 1
		end
		if k ≤ j
			right = j - 1
		end
	end
	return array
end

select!(array, k) = select!(array, 1, length(array), k)

end # module Fit
