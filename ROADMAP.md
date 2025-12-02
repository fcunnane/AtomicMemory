### *Atomic Memory™ (ROOM) Read Only-Once Memory — Project Roadmap*

## Overview

Atomic Memory™ (ROOM) is a CMOS-compatible *measurement–collapse* primitive that enforces deterministic **single-read semantics** for ephemeral secrets. The project is moving through progressive stages: from FPGA demonstration → formalization → ASIC minimal cell → integration with secure boot / PQC stacks → commercialization.

This roadmap outlines the intended trajectory.

---

## **1. Current Status (Q4 2025)**

### ✓ **FPGA Prototype**

* 1024-cell ROOM array implemented on Intel Cyclone V.
* Deterministic **same-cycle read-and-collapse** semantics.
* Avalon-MM interface + TCL test harness.
* Verified: no second read is possible after collapse.
* Repo cloned by early evaluators (industry + academic).

### ✓ **Threat Model & Use Case Definition**

* Focus on *preventing early and multi-use disclosure*.
* Protects ephemeral secrets against:

  * DMA / bus snooping
  * speculative execution leakage
  * cache residues / stale reads
  * cold boot & remanence
  * Rowhammer read-amplification
  * MMIO reordering
  * multi-core contention
  * zeroization race windows

### ✓ **Paper in review (TechRxiv + USENIX draft)**

* Formal semantics and collapse definition.
* Evaluation methodology.
* FPGA results.

---

## **2. Short-Term Goals (Next 1–3 Months)**

### 🔹 **Documentation + Repo Enhancements**

* Add `ARCHITECTURE.md` (high-level design + diagrams)
* Add `SECURITY.md` (threat model, non-goals, limitations)
* Add `FAQ.md` (glitching, DMA, clear-on-read vs. ROOM, etc.)
* Strengthen `LICENSE` language for non-commercial evaluation.

### 🔹 **Formalization**

* Finalize the read-once security definition (RO-IND or similar).
* Clarify synchronous vs. local-collapse behavior in FPGA vs. ASIC.
* Write formal model in TLA+, Coq, or pseudocode.

### 🔹 **Evaluation Expansion**

* Add test vectors for collapse detection.
* Add randomized basis / value experiments.
* Integrate lightweight side-channel measurement hooks.

---

## **3. Medium-Term Goals (3–9 Months)**

### 🔸 **ASIC Prototype (Minimal Cell)**

* Implement a small (8–32 cell) ASIC layout via

  * TinyTapeout,
  * Efabless MPW,
  * or IHP 130 nm shuttle.
* Goal: demonstrate **local combinational collapse** tied directly to the read gate (no global clock dependency).

### 🔸 **Integration With Real Systems**

* ROOM-backed ephemeral key handling for:

  * TLS 1.3 handshake secrets
  * PQC (Kyber) decapsulation keys
  * Secure boot seeds
  * Attestation keys
* Provide a **C library wrapper** for wolfSSL/wolfBoot/wolfHSM evaluation.
* Integrate with a small RISC-V SoC as a hardware co-processor.

### 🔸 **Robust Testing**

* Evaluate collapse under PVT (process/voltage/temp) variations.
* Measure collapse determinism under jitter and clock drift.
* Characterize fault-injection behavior at the architectural level.

---

## **4. Long-Term Goals (9–24 Months)**

### 🔶 **Silicon-Validated Primitive**

* Publish ASIC test results (collapse timing, entropy behavior, collapse path robustness).
* Deliver a stable **ROOM Cell Library** (RTL + GDS + PDK scripts).

### 🔶 **Standardization & Academic Visibility**

* Submit to USENIX Security 2026.
* Publish in IEEE T-IFS or CHES.
* Present at NIST, NCCoE PQC migration workshops.
* Draft an informational RFC / whitepaper for cryptographic community.

### 🔶 **Commercialization Path**

* Evaluation licenses available to hardware vendors.
* Integration targets:

  * microcontrollers
  * secure boot engines
  * embedded TPM-like co-processors
  * RISC-V cores
  * Smartcards / secure elements
* Explore partnerships with:

  * WolfSSL (wolfBoot / wolfHSM)
  * Rambus
  * Microchip
  * SiFive
  * Intel PSG
  * Government (DARPA DSO/MTO, NIST labs)

---

## **5. Non-Goals & Clarifications**

ROOM does **not** claim:

* tamper-proof or invasive-fault resistance
* glitch-proof behavior against professional lab equipment
* to replace TEEs or HSMs
* to store long-term keys

ROOM **does** claim:

* deterministic **single-use** semantics
* elimination of early-read and multi-read classes of leakage
* minimal architectural overhead
* suitability for ephemeral secrets where duration is short and exposure is dangerous

---

## **6. Guiding Principles**

* **Minimalism:** ROOM is a primitive, not a platform.
* **Verifiability:** Always provide measurable security properties.
* **CMOS-first:** Designs must remain compatible with standard digital flows.
* **Transparent threat model:** No sensational claims; focus on real, documented leakage surfaces.
* **Open academic ecosystem:** Non-commercial availability for research and peer review.
* **Commercial clarity:** Paid licensing for embedded, ASIC, or commercial deployments.

---

## **7. Contact**

For evaluation, academic use, or collaboration inquiries:
**QSymbolic LLC**
Contact: frank@qsymbolic.com

