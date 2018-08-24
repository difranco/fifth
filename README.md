# Fifth

A possibilistic-probabilistic logic language using an adaptive evaluation strategy to be both general purpose and purely 
declarative. In the late stages of design and the early stages of implementation.

The system consists of the high-level language itself, and a VM which is inspired by the semantics of the language and takes 
advantage of the high-level language runtime's collection of statistics on hot traces to optimize for data-flow oriented 
computation.

## VM

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

### Architecture specifics

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

### Architecture advantages

The main advantage over a VLIW architecture, which it resembles, is that it is self-scheduling.
The main advantage over a CPU is that it can be programmed in SIMD style for essentially unbounded amounts of data.
The main advantage over a GPU is that it can accomodate arbitrarily complex control flow as well as a CPU without giving up
the ability to exploit lack of control flow.

General advantages are that the architecture is conceptually simple and uniform and moves much of the complexity up into
software while still being programmable in a familiar, CPU-like way, but in a way that incrementally scales to a GPU-like
style with the corresponding benefits.

### VM interpreter

pass

## Language

Described in papers for PLP 2017 and 2018, to be summarized here.
