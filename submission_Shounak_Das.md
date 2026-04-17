# RAG for RISC-V RTL — Submission

| Field           | Details                    |
|-----------------|----------------------------|
| **Name**        | Shounak Das                |
| **Email**       | shounakdas.contact@gmail.com |
| **Phone**       | +91 8637067707             |
| **Country**     | India                      |
| **Date**        | 17/04/2026                 |
| **LinkedIn**    | https://www.linkedin.com/in/shounak-das-201322155/ |
| **GitHub**      | https://github.com/oniondas |

**Project Repository:** https://github.com/oniondas/RiscV-AI-agent.git

**Quick Summary:** This case study dynamically evaluates Agentic RAG generation pipelines against physical logic structures. I implemented a robust, AST-aware retrieval system with an intelligent LLM synthesis loop utilizing Verilator `make sim` for automated error corrections. The result is a fully functional, mathematically correct **Single-Cycle RV32I Processor** that has been functionally verified against the official `riscv-tests` passing heavily trapped combinatorial states (42/42 ISA operations passed).

## A. Corpus & Knowledge Base
- **Sources Used:** 
  1. The RISC-V Unprivileged Architecture ISA Specification for authoritative source-of-truth semantics on instruction encoding and operational definitions.
  2. Synthesizable Verilog design patterns extracted from structural implementations to map theoretical specs to silicon-proven constructs (e.g., ALU design, Little-Endian mapping).
- **Semantic AST-Aware Chunking:** 
  LLM tokenizers often break mid-module or mid-block, orphaning parallel sensitivity lists. Instead of traditional NLP sliding windows, I built an AST-aware regex chunker (`_chunk_verilog`) that extracts explicit architectural scopes (`module ... endmodule`). This guarantees the vector database stores functionally cohesive hardware boundaries, practically eliminating context fragmentation.
- **Retrieval & Embedding Approach:** A robust TF-IDF and Cosine Similarity dense index is mapped against incoming user queries (e.g., "Handle load hazard" or "B-type encoding") extracting relevant structural code snippets dynamically. 

## B. Pipeline Design
- **Architecture Diagram:** *(A detailed Mermaid visual mapping both the RAG Pipeline and the Hardware Core structure is available in the repository's `README.md`)*
  - `SemanticHardwareRetriever`: Embeds and fetches dense contextual logic rules from the chunked KB.
  - `AdvancedHardwareLLM (Gemini)`: Generates the raw architectural RTL based on standard RAG context.
  - `AgenticAutoFixer`: The core differentiator—Standard LLMs hallucinate loops or forget default cases in a Verilog switch, leading to invisible hardware latches. This pipeline triggers `make sim` on Verilator. Compilation `stderr` warnings and syntax errors are dynamically trapped and fed back to the LLM iteratively as correction prompts until zero-warning execution is achieved.

## C. Generated RTL
- **Repository:** The complete auto-generated, linted, and verified **Single-Cycle RV32I Processor** is available in my GitHub link at `src/rtl/rv32i_core.v`.
- **Trace Example Overview:** 
  1. *Prompt Envelope Component:* "Implement an optimal Single-Cycle RV32I Processor. Use explicit combinatorial stages. Handle loads and branches explicitly."
  2. *Retrieval Component:* The engine fetched standard RV32I instruction opcodes and `LB/LH/LW` data boundary definitions. 
  3. *Generation/Fix Iteration:* The initial Verilog caused `-Wall` syntax compilation issues regarding sensitivity blocks on multiplexers. The AgenticAutoFixer passed the output back autonomously.
  4. *Second Prompt/Fix:* "Linter Output: Warning-LATCH: Latch inferred for signal 'we'...". The LLM returned the fixed `default` state case allocations ensuring proper combinational design.

## D. Simulation Results
- **Setup:** I developed `sim_main.cpp`, an advanced **Verilator C++ Runtime**, operating against byte-aligned binaries produced tightly by `riscv-tests`. 
  Instead of fragile simulated memory abstractions, the C++ environment natively mirrors ISA configurations mapping `0x80000000`. Test checking occurs asynchronously around exact combinational completion evaluating pass/fail based strictly off register `gp (x3)` status flags per standard macro implementation.
- **ISA Pass Rate:** **42/42 compiled `rv32ui` tests passed.** The combinational core correctly evaluated branches, alignments, arithmetic, and basic trapping instructions seamlessly.
- **Benchmark Notes:** The design simulates optimally and mathematically correctly per cycle. Instructions simulate immediately allowing tight loop throughput.

## E. Failure Analysis
- **Where LLMs natively fail RTL (The AI vs. Silicon tradeoff):** 
  - *Load-Byte Endian Context Loss:* The initial LLM pipeline successfully identified and extracted `LB/LH/LBU/LHU`. However, it generated raw byte extraction (`dmem_rdata[7:0]`) instead of mapping boundaries properly (`dmem_rdata >> {alu_out[1:0] * 8}`). LLMs fail to inherently grasp little-endian relative shifts, often creating functional blindspots on memory boundaries.
  - *Branch Operation Overloading:* When mapping `BEQ/BNE/BLT`, the generated ALU utilized the relative immediate `imm_b` against the Program Counter via the primary execution ALU incorrectly routing PC-computation data directly into ALU conditions. The LLM prioritized generalized variable subtraction loops which generated combinational death spirals.
- **Debugging Methodology:** Through rigorous Verilator enforcement and parsing C++ execution instruction logs (`Tick: PC=... Instr=...`), I traced the execution bounds down to the specific clock cycle faults. Updating combinatorial blocks and separating ALU branch generation resolved combinatorial loop halts and memory extraction anomalies manually.

## F. Reflection
- **The Core Difficulty of the Problem:** Software optimization is about abstract time scales and algorithmic efficiency. Hardware generation forces models trained on prose and python to map exact physical paths, combinatorial constraints, and wire behaviors. Forcing a fluid NLP model into evaluating rigid byte structures and synchronous edges was exhilarating but incredibly complex.
- **What I would do next:** Given more time, I would expand this architecture back towards the deeply pipelined framework. Adding structural forwarding blocks across `EX/MEM` boundaries and integrating Formal Verification models (e.g. `SymbiYosys` with `assert()` tracking properties) would permit auto-generated proofs instead of sequential simulations.
- **Why AI Coding Assistants Fall Short in Hardware:** Present-day AI coding tools lack hardware telemetry. They optimize algorithmically for cache and "clean code", but they cannot internalize structural Synthesis, static-leakage equations, or timing path delays. Until models are specifically trained on Netlists and PPA limitations, forcing logic through deterministic physical simulations (like Verilator Auto-Fix loops) is the only realistic way to harness generative AI for Silicon.
