# Reference FPGA Implementation (Cyclone V)

This directory contains the reference RTL modules, precompiled FPGA images, and optional TCL test scripts for the atomic measurement–collapse primitive. This primitive is a CMOS-compatible hardware measurement–collapse mechanism that enforces single-read semantics: the first qualified read returns the stored byte, and the act of measurement deterministically triggers an irreversible collapse event. After collapse, the cell produces only obfuscated or PRNG-derived outputs, ensuring that the original value cannot be recovered. The implementation demonstrates deterministic first-read disclosure, basis-conditioned access control, and atomic one-way state transitions across a bank of independent memory cells.

The provided `.sof` files allow direct hardware validation without any
additional bus interface modules.

> **Status:** Research Artifact Release  
> **License:** Non-commercial use only (see LICENSE below)  
> **Patent Pending:** US 19/286,600  
> **Target Hardware:** Intel Cyclone V (5CSEBA6 / DE-SoC)

---

## 📦 Directory Contents

| File / Folder                    | Description                                                                |
|----------------------------------|----------------------------------------------------------------------------|
| `fpga/collapse_cell.sv`          | Core primitive read-once cell used in the paper                           |
| `fpga/collapse_bank.sv`          | 1024-cell bank with shared entropy/obfuscation bus                        |
| `fpga/Atomic1024Bank.sof`        | Clean 1024-cell bitstream (no SignalTap – fastest flash path)             |
| `fpga/SignalTap.sof`             | Instrumented build with hands-free auto-running demo                      |
| `fpga/SignalTap.stp`             | Pre-configured SignalTap file – open → Run → observe collapse timing      |
| `fpga/program_clean.bat`         | Windows one-click flash (clean version)                                   |
| `fpga/program_clean.sh`          | Linux one-click flash (clean version)                                     |
| `fpga/program_signaltap.bat`     | Windows one-click flash (SignalTap demo)                                  |
| `fpga/program_signaltap.sh`      | Linux one-click flash (SignalTap demo)                                    |
| `tcl/`                           | Optional System Console TCL scripts for automated testing                 |
| `images/`                        | One-cycle disclosure + destroy waveform from the associated paper         |
| `ROADMAP.md`                     | Project roadmap and planned ASIC/FPGA development stages                  |
| `LICENSE.md`                     | Non-commercial license                                                     |
| `README.md`                      | This file                                                                  |


---

## 🧩 RTL Overview

### `collapse_cell.sv`

Implements the measurement–collapse read-once memory (ROOM) primitive:

- `INIT` loads value and basis  
- **First correct-basis read discloses the stored value and collapses the cell atomically**  
- All subsequent reads return post-collapse obfuscated bytes  

Key internal state:

- `basis_valid_q`  
- `armed_q`  
- `collapsed_q`

### `collapse_bank.sv`

Implements the full 1024-cell array. This module provides:

- Parallel instantiation of 1024 `collapse_cell` units  
- Address decode and routing for selecting a single active cell  
- Uniform broadcast of metadata inputs (basis byte, read pulse, init pulse)  
- Aggregation of output paths (`data_o`, `collapsed_q`, status, etc.)  
- Optional ring-oscillator (RO) drive to support post-collapse oscillation-based
  entropy/obfuscation at the bank level

The RO path is only active **after collapse** and contributes to the
post-collapse obfuscated output stream when enabled. It does not affect
first-read correctness or collapse semantics.

---

## 🔧 FPGA Images Provided

### `Atomic1024Bank.sof`

- Clean build without instrumentation  
- Used for simple demonstrations and black-box verification

### `SignalTap.sof`

- Same RTL with SignalTap probes enabled  
- Captures internal collapse timing at 50 MHz

Probed signals (see `SignalTap.stp`):

- `read_pulse`  
- `basis_in[7:0]`  
- `basis_valid_q`  
- `armed_q`  
- `collapsed_q`  
- `data_o[7:0]`  
- `valid_out` (if present)

---

## 🗂️ TCL Test Scripts (`tcl/`)

These optional scripts are provided for users who wish to automate
interactions, drive sequences, or reproduce the internal test flow.

Example capabilities include:

- Automated read sequences  
- Basis sweep testing  
- Collapse confirmation cycles  
- Bulk sampling into local logs  

These scripts do **not** depend on any bus interface HDL included in this
artifact. Users may adapt them for their own host interface, GPIO
sequencer, or System Console workflows.

---

## 🖥️ Hardware Usage

1. Open **Quartus Programmer**
2. Load either `Atomic1024Bank.sof` or `SignalTap.sof`
3. Program the DE-SoC using USB-Blaster
4. (Optional) Open **SignalTap** to observe:
   - First-read disclosure  
   - Collapse event  
   - Post-collapse output evolution  

No Avalon-MM slave or external IP wrapper is required to use these images.

---

## 📄 License

See the full `LICENSE.md` file.  
A non-commercial research license applies.

---

## 📜 License (Summary)

- Non-commercial research, teaching, and evaluation permitted  
- Commercial use requires a separate license from QSymbolic LLC  
- Patent rights granted for **non-commercial** use only  
- Attribution required  
- No warranty; no liability  

This summary is informational only. The full text in `LICENSE.md` controls.

---

## 📚 Citation

If you use this artifact in academic work, please cite the associated paper:

> **Cite as:**  
> Francis X. Cunnane III. *A CMOS Measurement–Collapse Primitive for Ephemeral Secrets in Post-Quantum Cryptography.* TechRxiv. December 02, 2025.  
> https://doi.org/10.36227/techrxiv.176463742.23048082/v3

**BibTeX example:**

```bibtex
@misc{cunnane2025measurementcollapse,
  author       = {Cunnane III, Francis X.},
  title        = {A CMOS Measurement--Collapse Primitive for Ephemeral Secrets in Post-Quantum Cryptography},
  year         = {2025},
  month        = dec,
  note         = {TechRxiv},
  doi          = {10.36227/techrxiv.176463742.23048082/v1},
  url          = {https://doi.org/10.36227/techrxiv.176463742.23048082/v1}
}

