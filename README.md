# **WISC-S25-MIPS-CPU Project**

## **Overview**

The **WISC-S25-MIPS-CPU** is a MIPS-like RISC-based microprocessor architecture implemented at the Register-Transfer Level (RTL). Designed for educational and experimental purposes, this processor features a classic 5-stage pipeline (Fetch, Decode, Execute, Memory, Writeback) and incorporates advanced architectural elements such as instruction and data caches and dynamic branch prediction for improved performance.

This project leverages a Makefile-based workflow to streamline simulation, testing, logging, and file management. The included automation tools help facilitate rapid iteration, thorough verification, and reproducibility of results during development.

This repository serves as a complete reference for the CPU architecture, testbench setup, and usage instructions for building and running simulations or hardware demos.

---

## **Project Structure**

```text
/WISC-S25-MIPS-CPU
├── Extra-Credit/              # Directory containing extra-credit design and synthesis related files
│   ├── designs/               # Directory containing pre-synthesis design files
│   ├── outputs/               # Directory containing top level generated test output files
│   ├── Synthesis/             # Directory containing synthesis related files
│   └── tests/                 # Directory containing all related testbench files used for testing
├── Phase-1/                   # Directory containing Phase-1 files for a single cycle implementation of the CPU
│   ├── designs/               # Directory containing pre-synthesis design files
│   ├── outputs/               # Directory containing top level generated test output files
│   └── tests/                 # Directory containing all related testbench files used for testing
├── Phase-2/                   # Directory containing Phase-2 files for a 5-stage pipeline based implementation with dynamic branch prediction
│   ├── designs/               # Directory containing pre-synthesis design files
│   ├── outputs/               # Directory containing top level generated test output files
│   └── tests/                 # Directory containing all related testbench files used for testing
├── Phase-3/                   # Directory containing Phase-3 files for a 5-stage pipeline with dynamic branch prediction and caches
│   ├── designs/               # Directory containing pre-synthesis design files
│   ├── outputs/               # Directory containing top level generated test output files
│   └── tests/                 # Directory containing all related testbench files used for testing
├── Scripts/                   # Directory containing scripts for automating testing tasks
├── TestPrograms/              # Directory containing assembly test files to load into the CPU
├── Makefile                   # Makefile for automating tasks
```

---

## **Dependencies**

- **Python 3.x**: Required to run the `execute_tests.py` script.
- **Make**: For running the Makefile commands.
- **Verilog Simulator**: E.g., ModelSim, XSIM, or any simulator capable of running Verilog tests.

---

## **Installation**

1. Clone the repository to your local machine:
   ```bash
   git clone https://github.com/InterGalactic946/WISC-S25-MIPS-CPU
   cd WISC-S25-MIPS-CPU/
   ```

2. Ensure that Python 3 and Make are installed on your system:
   - Python 3: [Installation Guide](https://www.python.org/downloads/)
   - Make: [Installation Guide](https://www.gnu.org/software/make/)

3. Install required Python dependencies (if any):
   ```bash
   pip install <dependencies>
   ```

---

# **Makefile for Synthesis, Simulation, Logs, and File Collection**

This Makefile is designed to streamline the process of managing synthesis, running simulations, viewing logs, and collecting design/test files. Below are the available targets and their respective usage instructions.

---

## **Table of Contents**
1. [Synthesis](#synthesis)
2. [Run Simulations](#run-simulations)
3. [View Logs](#view-logs)
4. [Collect Files](#collect-files)
5. [Clean Directory](#clean-directory)

---

## **Synthesis**
Generates a synthesized Verilog netlist and timing constraints using Synopsys Design Compiler.

### Usage:
```bash
make synthesis
```
### Description:
- Synthesizes the design to a Synopsys 32-nm Cell Library.
- Generates: a compilation log file, min/max delay reports, an area report, a `.vg` file (netlist), and a `.sdc` file (timing constraints).
- Automatically runs only if source files or the synthesis script have been updated.

### Output Files:
- `cpu_area.syn.txt`(Area Report)
- `cpu_power.syn.txt` (Power Report)
- `cpu_max_delay.syn.txt` (Max Delay Report)
- `cpu.vg` (Netlist)
- `cpu.sdc` (Timing Constraints)

---

## **Run Simulations**
Executes test cases in different modes (CMD, GUI, save waveforms).

### Usage:
```bash
make run
make run <mode> <args>
```

### Modes:
- `v` - View waveforms in GUI mode
- `g` - Run in GUI mode
- `s` - Save waveforms
- `c` - Run in CMD mode

### Args:
- `a`  - All tests
- `as` - Assemble a test file

### Examples:
1. Run all tests in CMD mode:
   ```bash
   make run
   ```
2. Run all tests and save waveforms:
   ```bash
   make run s a
   ```
3. Run a specific test in GUI mode:
   ```bash
   make run g
   ```
4. Run a specific test after assembly in CMD mode:
   ```bash
   make run c as
   ```

---

## **View Logs**
Displays logs for synthesis, compilation, or test transcripts from a selected directory.

### Usage:
```bash
make log <type> <sub_type> <args>
```
### Log Types:
1. **Synthesis Reports (`s`)**
   - `a`: Area report
   - `p`: Power report
   - `x`: Max delay report
   - Example:
      ```bash
      make log s a
      ```
2. **Compilation Logs (`c`)**
   - Example:
      ```bash
      make log c
      ```
3. **Test Transcripts (`t`)**
   - Example:
      ```bash
      make log t
      ```

---

## **Other Useful Commands**
Commands to "kill" vsim on numerous spawned instances and check design files.

### Usage:
```bash
make kill
make check
```

### Examples:
1. This will kill all currently spawned instances of vsim to give a fresh start:
   ```bash
   make kill
   ```
2. This will check all design files of a selected directory to be compliant for synthesis:
   ```bash
   make check
   ```

---

## **Clean Directory**
Removes generated files to clean up the workspace in a selected directory.

### Usage:
```bash
make clean
```

---

## **Notes**
- Ensure you have all required dependencies installed (e.g., Synopsys tools, Python).
- For troubleshooting or additional details, refer to individual target sections.

---

## **Acknowledgments**
Special thanks to contributors and open-source tools that made this project possible.
