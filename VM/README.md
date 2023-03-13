
# VM: Route Machine

The adaptive evaluation techniques operating at the high level identify commonly informative traces, which are mostly data 
flows with mostly limited / no control components. Data is fed through these first to accumulate information as quickly as 
possible about the query. This suggests that hardware (virtual and physical) should be oriented towards setting up data 
flows and streaming data through them, but also that small exceptions to those flows should be easy to accomodate when they 
arise. Something a bit more flexible and high level is called for than an FPGA, where changing a configuration is a very 
expensive operation, and much of the computation is bit-oriented while the rest is done in highly specialized functional 
units.

We seek a middle ground between FPGA and CPU, somewhere in the same region of design space as DSP and GPGPU architectures, 
but with fewer compromises than these make. For a virtual machine, it should also be easy to map the execution of parts of 
the virtual machine computation onto heterogeneous supporting hardware - especially the CPU-GPU and CPU-GPU-DSP combinations 
that are ubiquitous on desktop and mobile consumer platforms and in cloud and other clusters.

## Architecture specifics

The architecture to satisfy these desiderata is a systolic array of cores with one-instruction-set (1IS) ISA. The core 
architecture is similar to other 1IS architectures, but the move operation used in other is replaced by a “connect” 
operation which creates a persistent connection between the ports referenced instead of transiently moving a single datum 
from one to the other. This permits all redundant moves in a static data flow to be elided, while retaining the flexibility 
of specifying each individually, since connections can be changed just before moving data into a modified data flow just as 
the data could be moved one step at a time through the new data flow with new move instructions. This is a novel 
architectural idea as far as I know.

Like many other 1IS architectures, this one is transport triggered, that is, moving data into a data flow causes it to 
propagate as far through it as there are live connections set up. Normal correct use will have a path from source memory to 
sink memory or a discarding sink (guard or filter) for all possible input data in a flow. In hardware, the preferred way to 
arrange this is by using clockless logic at the boundaries of functional units, and perhaps around smaller clock domains or 
ubiquitously throughout the cores and their network. In software, the architecture maps cleanly onto the actor model.

Nonetheless, there must still be explicit moves to get data into the flows set up in the first place. These are restricted 
to loads from memory. The usual form is one that loads an entire contiguous range of words from memory in sequence, to 
exploit the benefit of the data flow being set up. Another can be parameterized by a stride as well, so as to be able to 
pull members out of a contiguous set of structures in memory.

Likewise, store functional units will accept as parameters a base memory address and stride, and perhaps also a word size, 
and the base address will automatically increment as words arrive, similar to how a program counter auto-increments.

Guards were mentioned; they are the residual form of control, similar to masked instructions in GPUs. They drop rather than 
propagate data when a control flag is false. This is also the main form of semantic synchronization required, since a datum 
and the corresponding flag must arrive together. This means it should be used in a pattern like filters in list-oriented 
programming, where a predicate is run on each datum to determine whether it is kept.

## Functional unit specifications

All these assume a word size to be established. There may be different word sizes in a single unit, in which case
an additional unit type should be defined to convert from groups of smaller words to larger words and back.

The fixed operations can be implemented as combinatorial logic or a hardware LUT. LUT may make more sense for e.g. 
multiplication and division, especially with a number representation such as Type 2 unums. The LUT type unit can be loaded 
with a custom LUT.

All ports are mapped to addresses in a uniform address space. If there are small and large word sizes, for example bytes and 
32-bit words, the small size can be used for register-like addressing and the large size for memory-like addressing. But 
typically, in RISC style, connect operations will use the short address length, or a custom length, and all others will use 
the long word for operations.

In a multi-core setup, most or all of the larger address space should be shared among cores.

### Single instruction: Connect

Instruction specifies a source address and a destination address.
Upon execution, addresses are connected.

We may consider allowing connections to be made between any pair of addresses, including memory addresses, which could be 
used to implement fan-out in an alternative way to the fanout unit below, and could be backed by a routing table. This could 
also be the primary or only mechanism for core to core communication.

Variants

* Both addresses are short (register-register style)
* Both addresses long (memory-memory style)
* One address is short and the other long (register-memory style)

### Adder

Input ports: two words to be added
Output ports: sum word and carry word (essentially upper and lower halves of sum)

Once words arrive on both inputs, consumes and sums them and publishes sum on output ports.

### Multiplier

Input ports: two words to be multiplied
Output ports: four words of the product

Once words arrive on both inputs, consume them and publish the product on the output ports.

### Divider

As multiplier, but for division.

Has eight output ports, four for quotient and four for remainder.

### Subtracter

As adder, but for subtraction.

### Negater

Input port: one word to be negated.
Output port: negated word.

When input arrives, consume it and publish negation on output.

### Bitwises

All have one  or two words as input and one word output as appropriate.

* And
* Or
* Not
* Nand
* Nor

### Look Up Tables

LUTs have 1-2 input ports and 1-8 output ports.

In addition, they have a set of input ports, which number in the size of an input word to the power of the number of input 
ports times the number of output ports. When the location(s) at the offset of an input port are written with the outputs, 
therafter the LUT returns the given output for that input.

Variant: To save address space, the input ports to set the LUT may accept input-output tuples. Then, there will be a set of 
2-10 ports to compute, and a set of the same number of ports to revise entries in the LUT.

### Filter

Input ports: N inputs, and 1 flag word
Output ports: N outputs

When a flag word arrives on the flag input, the filter copies any inputs which have arrived to the corresponding outputs if 
the flag is nonzero, else it discards them.

Variant: the filter waits for all inputs to arrive before proceeding.

### Fanout

1-way variant

Input port: a word

Output ports: two copies of the word

N-way variant

Input ports: a word and an integer n specifying how many copies to make (up to a bound N fixed in the hardware)

Output ports: N words

When a word to be copied and n both arrive, publishes n copies on the first n output ports.
Discards both inputs if n < 1 or n > N.

### Fetcher

Input ports: a source address and a synchronization flag

When the source address is set, fetches and executes the instruction at that address, and increments the source address. If 
the synchonization flag is set to a nonzero value, waits until it is not before fetching another instruction, else 
immediately fetches and executes another (will still block if target ports of that connection are occupied).

Instruction may specify that the synchronization flag be set or cleared.

Instruction format is (synchronization flag, source to connect, target to connect), with short or long addresses for either, 
or (synchronization flag, constant to load, target address to load).

### Loader

Input ports: A target address, a base address, a count, and a stride.
Output ports: None

When the target address and base address are set, checks whether the count and stride are also set. If count is set, copies 
a block of size count starting at base address to target address. If stride is also set, increments base address by stride 
instead of by 1 between copying each word. At the end, base address is at the position of what the next address to be copied 
would have been with the given stride, and target address remains as it was.

### Storer

Input ports: A word to store, a target address, and a stride.
Output ports: None

When a word to store arrives and target address is set, consumes and copies the word to target address, and increments the 
target address by stride if set, else by one.

## Architecture advantages

The main advantages over a VLIW architecture, which it resembles, is that redundant instructions need not be repeated in 
unchanging data flows. Secondarily, it is to some extent self-scheduling.

The main advantage over a CPU is that it can be programmed in SIMD style for essentially unbounded amounts of data.

The main advantage over a GPU is that it can accomodate arbitrarily complex control flow as well as a CPU without giving up
the ability to exploit lack of control flow.

General advantages are that the architecture is conceptually simple and uniform and moves much of the complexity up into
software while still being programmable in a familiar, CPU-like way, but in a way that incrementally scales to a GPU-like
style with the corresponding benefits.

## Implementation

WIP
