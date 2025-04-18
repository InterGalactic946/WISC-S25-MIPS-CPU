##################################################
# Makefile for handling check, run, log, and clean targets with arguments.
# This Makefile supports the following goals:
# - check: Checks if Verilog design files are compliant.
# - synthesis: Synthesizes design to Synopsys 32-nm Cell Library.
# - kill: Closes all vsim instances started from the script.
# - run: Executes tests with specified arguments.
# - log: Displays logs based on the provided log mode.
# - clean: Cleans up generated files in the specified directory.
#
# Usage:
# - make check                  - Checks if Verilog design files are compliant.
# - make kill           	    - Closes all started vsim instances from the script.
# - make synthesis              - Synthesizes design to Synopsys 32-nm Cell Library.
# - make run <mode> (as) (a)    - Assemble and run tests in a specified directory with a selected mode (optionally all tests in the directory).
# - make log <log_type> (a|p|x) - Display logs for a specified directory and log type.
# - make clean                  - Clean up generated files in a specified directory.
#
# Example:
# - make check  - Checks all .v design files that are not testbenches for compliancy.
# - make run v  - Views waveforms in a specified directory.
# - make log c  - Displays compilation logs for a specific directory.
# - make clean  - Cleans up generated files in a specific directory.
##################################################

# Default target: Shows usage instructions when no target is specified.
# This target will be executed if no other target is provided.
# It helps users understand how to use the Makefile.
default:
	@echo "Usage instructions for the Makefile:"
	@echo "  make check 	              - Checks all .v design files for compliancy within a selected directory."
	@echo "  make kill 	              - Closes all started vsim instances from the script."
	@echo "  make synthesis              - Synthesizes design to Synopsys 32-nm Cell Library."
	@echo "  make run <mode> [as] [a]    - Run tests in a specified directory with a selected mode (c,s,g,v) and optionally assembles files."
	@echo "  make log <log_type> [a|p|x] - Display logs for a specified directory and log type."
	@echo "  make clean 	              - Clean up generated files in a specified directory."

# Handle different goals (run, log, clean) by parsing arguments passed to make.
ifeq ($(firstword $(MAKECMDGOALS)), run)
  runargs := $(wordlist 2, $(words $(MAKECMDGOALS)), $(MAKECMDGOALS))
  # Prevent make from treating arguments as file targets for 'run'.
  $(eval $(runargs):;@true)
else ifeq ($(firstword $(MAKECMDGOALS)), log)
  logargs := $(wordlist 2, $(words $(MAKECMDGOALS)), $(MAKECMDGOALS))
  # Prevent make from treating arguments as file targets for 'log'.
  $(eval $(logargs):;@true)
endif

# Declare phony targets.
.PHONY: default check synthesis kill run log clean $(runargs) $(logargs)


##################################################
# Target: check
# This target checks Verilog design files in a specified directory.
# Usage:
#   make check
##################################################
check:
	@ cd Scripts && python3 execute_tests.py -c


##################################################
# Target: kill
# This target closes all started vsim instances.
# Usage:
#   make kill
##################################################
kill:
	@echo "Closing all started vsim instances..."
	@ pkill vish -9


##################################################
# Target: synthesis
# This target runs the synthesis script and produces log files.
# Usage:
#   make synthesis
##################################################
synthesis:
	@cd Extra-Credit/Synthesis && bash ./auto_syn.sh


##################################################
# Target: run
# This target runs tests with the specified arguments:
# - <mode>: Test mode (default or one of `v`, `g`, `s`, `c`).
# - <as>: Optional flag for assembling an input file.
# - <a>: Optional flag for additional arguments (e.g., 'a' to run all tests in a specific mode).
# Usage:
#   make run <mode> [as] [a]
##################################################
run:
	@if [ "$(words $(runargs))" -eq 0 ]; then \
		cd Scripts && python3 execute_tests.py -a; \
	# Check if the number of arguments is 1 or more, with valid mode. \
	elif [ "$(words $(runargs))" -ge 1 ]; then \
		case "$(word 1, $(runargs))" in \
			v) mode=3 ;;  # View waveforms. \
			g) mode=2 ;;  # GUI mode. \
			s) mode=1 ;;  # Save waveforms. \
			c) mode=0 ;;  # CMD mode for specific test number. \
			*) \
				echo "Error: Invalid sub-mode for tests. Supported modes are v, g, s, or c."; \
				exit 1; \
				;; \
		esac; \
		# If there is a third argument ('a'), pass it to the Python script. \
		if [ "$(words $(runargs))" -eq 2 ] && [ "$(word 2, $(runargs))" == "as" ]; then \
			cd Scripts && python3 execute_tests.py -m $$mode -as; \
		elif [ "$(words $(runargs))" -eq 2 ] && [ "$(word 2, $(runargs))" == "a" ]; then \
			cd Scripts && python3 execute_tests.py -m $$mode -a; \
		else \
			cd Scripts && python3 execute_tests.py -m $$mode; \
		fi; \
	# If arguments are invalid or incomplete, print an error and usage. \
	else \
		echo "Error: Invalid arguments for 'run' target. Usage:"; \
		echo "  make run v|g|s|c [as] [a]"; \
		exit 1; \
	fi;


##################################################
# Target: log
# This target displays logs based on the provided log mode:
# - <log_type>: Type of log (either `s` for synthesis along with <report_type>, `c` for compilation logs, or `t` for transcript logs).
# Usage:
#   make log <log_type> [a|p|x]
##################################################
log:
	@if [ $(words $(logargs)) -ge 1 ]; then \
		case "$(word 1, $(logargs))" in \
		s) \
			case "$(word 2, $(logargs))" in \
			a) \
				echo "Displaying area report:"; \
				cat ./Synthesis/32nm_rvt/cpu/cpu_area.syn.txt ;; \
			p) \
				echo "Displaying power report:"; \
				cat ./Synthesis/32nm_rvt/cpu/cpu_power.syn.txt ;; \
			x) \
				echo "Displaying max delay report:"; \
				cat ./Synthesis/32nm_rvt/cpu/cpu_max_delay.syn.txt ;; \
			*) \
				echo "Error: Invalid sub-argument for 's'. Use one of: a, p, x."; \
				exit 1 ;; \
			esac ;; \
		c) \
			cd Scripts && python3 execute_tests.py -l c ;; \
		t) \
			cd Scripts && python3 execute_tests.py -l t ;; \
		*) \
			echo "Error: Invalid log type. Usage:"; \
			echo "  make log s <a|p|x>"; \
			echo "  make log c"; \
			echo "  make log t"; \
			exit 1 ;; \
		esac; \
	else \
		echo "Error: Missing or invalid arguments for 'log' target. Usage:"; \
		echo "  make log s <a|p|x>"; \
		echo "  make log c"; \
		echo "  make log t"; \
		exit 1; \
	fi


##################################################
# Target: clean
# This target cleans up generated files in a specified directory:
# Usage:
#   make clean
##################################################
clean:
	@echo "Available directories to clean:"; \
	# List the top-level directories in the current directory. \
	top_level_dirs=$$(ls -d */ | grep -E 'Phase-1|Phase-2|Phase-3|Extra-Credit'); \
	if [ -z "$$top_level_dirs" ]; then \
		echo "No valid top-level directories (Phase-1, Phase-2, Phase-3, Extra-Credit) found."; \
		exit 1; \
	fi; \
	PS3="Please select a top-level directory (Phase-1, Phase-2, Phase-3, Extra-Credit) to clean: "; \
	select top_level_dir in $$top_level_dirs; do \
		if [ -n "$$top_level_dir" ] && [ -d "$$top_level_dir" ]; then \
			echo "Cleaning up generated files in $$top_level_dir..."; \
			rm -rf "$$top_level_dir/dump.vcd" "$$top_level_dir/tests/output/" "$$top_level_dir/outputs/verilogsim.log" "$$top_level_dir/outputs/verilogsim.trace" "$$top_level_dir/tests/WORK/"; \
			echo "Cleanup complete."; \
			break; \
		else \
			echo "Invalid selection, please choose a valid top-level directory."; \
		fi; \
	done