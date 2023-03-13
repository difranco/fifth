module BitTools

export rbitvec, invert_at_indices, select, lemur64, bitview, hammingdistances

using RandomNumbers
using Random
using Distributions

rng = Xorshifts.Xoshiro128Plus(0xdeadbeef)

@inline function lemur64(seed :: UInt128 = 0x00000000000000001d93c17c35f59716) #UInt128(2131259787901769494)
	s = (seed * 0x0000000000000000da942042e4dd58b5) #UInt128(15750249268501108917)
	r = unsafe_trunc(UInt64, s >> 64)
	return r, s
end

@inline function rbitvec(len :: Integer, occ :: Integer, rng = rng)
	# Returns a random bit vector of length len
	# with occ one bits and len-occ zero bits
	return BitVector(shuffle!(rng, [zeros(Bool, len - occ); ones(Bool, occ)]))
end

using Distributions: Beta
beta = Beta(5, 5)

@inline function rbitvec(len :: Integer)
	# Returns a random bit vector of length len
	# and occupancy Beta(5,5) between 1 and len
	return rbitvec(len, Int(floor(len * rand(rng, beta)) + 1))
end

# Re. bitView below
# https://discourse.julialang.org/t/reinterpret-as-a-complex-struct/24784/4
# https://discourse.julialang.org/t/dealing-with-complex-c-structure/9045/2
# https://github.com/JuliaGraphics/Gtk.jl/blob/d0a218011bbb3e30934bdabd780131d1eaa6e3d0/src/gdk.jl#L74

# reshape parameter arrays to vectors and concatenate, recording sequence
# of dimensions of sources
# then, reinterpret as UInt64[] and set as BitArray chunks
# reshape(reinterpret(UInt8, a.chunks), 4,2)
# this works as expected: @views a = reinterpret(UInt64, b)

@inline function obj2array(o)
	s = sizeof(o)
	o = unsafe_wrap(Array{UInt64}, reinterpret(Ptr{UInt64},pointer_from_objref(o)), s)
	return (o, s)
end

function bitview(x)
	b = BitVector()
	(b.chunks, s) = obj2array(x)
	b.dims = (0,) # observed this behavior with normal constructor
	b.len = 8*s
	return b
end

@inline function invert_at_indices(x::BitVector, inds)
	# returns copy of x with bits flipped at positions given in inds
	out = copy(x)
	map!(!, view(out, inds), x[inds])
	return out
end

function hammingdistances(data :: BitMatrix)
	(dim, len) = size(data)
	r = zeros(UInt16, len, len)
	for i in 1:len
		for j in 1:i
			r[i,j] = r[j,i] = sum(data[:,i] .!= data[:,j])
		end
	end
	return r
end

export hypercode, hypersum, hyperdiff, hyperprod, hyperquot, distance

function hypercode(o, setbits = 16, length = 4096)
	localrng = Xorshifts.Xorshift64(hash(o))
	return rbitvec(length, setbits, localrng)
end

@inline function hypersum(a, b)
	# this will only perform as expected for sparse codes, up to capacity
	return a .⊻ b
end

@inline function hyperdiff(a, b)
	return a .& .!b
end

@inline function hyperprod(a, b)
	# permutation version is better for many uses
	return a .⊻ b
end

@inline function hyperquot(a, b)
	# permutation version is better for many uses
	return a .⊻ b
end

@inline function distance(a, b)
	return sum(a .⊻ b)
end

end # module BitTools
