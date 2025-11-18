# ATOMIC MEMORY™ — Reference FPGA Implementation (Cyclone V)

This directory contains the reference RTL modules, precompiled FPGA
images, and optional TCL test scripts for the **Atomic Memory™ (ROOM)**
read-once primitive. The hardware demonstrates deterministic single-read
disclosure followed by irreversible collapse and post-collapse obfuscated
output behavior.

The provided `.sof` files allow direct hardware validation without any
additional bus interface modules.

> **Status:** Research Artifact Release  
> **License:** Non-commercial use only (see LICENSE below)  
> **Patent Pending:** US 19/286,600  
> **Target Hardware:** Intel Cyclone V (5CSEBA6 / DE-SoC)

---

## 📦 Directory Contents

File / Folder                        Description
-----------------------------------------------------------------------------------------
fpga/collapse_cell.sv                Core Atomic Memory(TM) read-once cell (production-ready, patent-pending)
fpga/collapse_bank.sv                1024-cell bank with peer-cascade and shared entropy bus
fpga/Atomic1024Bank.sof              Clean 1024-cell bitstream (no SignalTap – fastest flash)
fpga/SignalTap.sof                   Instrumented build with hands-free auto-running demo
fpga/SignalTap_demo.stp              Pre-configured SignalTap file – open → Run → perfect collapse every time
fpga/program_clean.bat               Windows one-click flash (clean version)
fpga/program_clean.sh                Linux/macOS one-click flash (clean version)
fpga/program_signaltap.bat           Windows one-click flash (SignalTap demo)
fpga/program_signaltap.sh            Linux/macOS one-click flash (SignalTap demo)
tcl/                                 Optional System Console TCL scripts for automated testing
Perfect_Atomic_Waveform.png          Exact one-cycle disclosure + destroy waveform from the TechRxiv paper
LICENSE.md                           MIT + Patent-Encumbered – commercial use requires license
README.md                            This file
-----------------------------------------------------------------------------------------


---

## 🧩 RTL Overview

### **collapse_cell.sv**
Implements the ROOM primitive:

- INIT loads value and basis  
- **First correct-basis read discloses the stored value and collapses the cell**  
- All subsequent reads return post-collapse obfuscated bytes  

Internal metadata:

- `basis_valid_q`  
- `armed_q`  
- `collapsed_q`

### **collapse_bank.sv**
Implements the full 1024-cell Atomic Memory array. This module performs:

- Parallel instantiation of 1024 `collapse_cell` units  
- Address decode and routing for selecting a single active cell  
- Uniform broadcast of metadata inputs (basis byte, read pulse, init pulse)  
- Aggregation of output paths (`data_o`, `collapsed_q`, etc.)  
- Optional ring-oscillator (RO) drive to support post-collapse oscillation-based
  entropy generation at the bank level.

The RO path is only active **after collapse** and contributes to the
post-collapse obfuscated output stream when enabled. It does not affect
first-read correctness or collapse semantics.

---

## 🔧 FPGA Images Provided

### **`Atomic1024bank.sof`**
- Clean build without instrumentation  
- Used for simple demonstrations and black-box verification

### **`SignalTapCell.sof`**
- Same RTL with SignalTap probes enabled  
- Captures internal collapse timing at 50 MHz

Probed signals:

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

Example scripts may include:

- Automated read sequences  
- Basis sweep testing  
- Collapse confirmation cycles  
- Bulk sampling into local logs  

These scripts do **not** depend on any bus interface included in this
artifact. Users may adapt them for their own host interface, GPIO
sequencer, or System Console workflows.

---

## 🖥️ Hardware Usage

1. Open **Quartus Programmer**
2. Load either `1024bank.sof` or `SignalTapCell.sof`
3. Program the DE-SoC using USB-Blaster
4. (Optional) Open **SignalTap** to observe:
   - First-read disclosure  
   - Collapse event  
   - Post-collapse output evolution  

No Avalon-MM slave or external IP wrapper is provided or required.

---

## 📄 License

See the full `LICENSE` file.  
A non-commercial research license applies.

---

## 📜 **LICENSE (Summary)**

- Non-commercial research, teaching, and evaluation permitted  
- Commercial use requires a separate license from QSymbolic LLC  
- Patent rights granted for **non-commercial** use only  
- Attribution required  
- No warranty; no liability  

See `LICENSE` for the full legal text.

---

### Commercial Licensing  
QSymbolic LLC  
Email: **frank@qsymbolic.com**

---

## 📚 Citation

If used in academic work, please cite:
