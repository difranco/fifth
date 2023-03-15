# Fifth

A purely declarative relational language using an adaptive evaluation strategy to be both general purpose and efficient. In the late stages of design and the early stages of implementation.

The envisioned system consists of the high-level language itself, and a VM/hardware design which is informed by the semantics of the language and takes advantage of the high-level language runtime's collection of statistics on hot traces to optimize for data-flow oriented computation.

## High-level Language

System described in the following papers:

* “Information-gain computation.” https://arxiv.org/abs/1707.01550
* “Information-relational Semantics of the Fifth System.” PLP@ILP 2018: 75-82
* “Information-gain computation in the Fifth system.” Int. J. Approx. Reason. 105: 386-395 (2019)
* “Review and Research Proposal for Information Gain Driven Adaptive Evaluation for Purely Declarative Software.” In preparation

## Implementation

Under heavy construction. Prototype of population-based sampling for multi-objective parameter optimization complete. See “Adapt” directory. Likely to have many severe bugs.
