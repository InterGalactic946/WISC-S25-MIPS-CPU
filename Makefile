##################################################
# Makefile for handling check, run, log, and clean targets with arguments.
# This Makefile supports the following goals:
# - check: Checks if Verilog design files are compliant.
# - run: Executes tests with specified arguments.
# - log: Displays logs based on the provided log mode.
# - clean: Cleans up generated files in the specified directory.
#
# Usage:
# - make check          - Checks if Verilog design files are compliant.
# - make run <mode> (a) - Run tests in a specified directory with a selected mode (optionally all tests in the directory).
# - make log <log_type> - Display logs for a specified directory and log type.
# - make clean          - Clean up generated files in a specified directory.
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
	@echo "  make check 	      - Checks all .v design files for compliancy within a selected directory."
	@echo "  make run <mode> [a] - Run tests in a specified directory with a selected mode (c,s,g,v)."
	@echo "  make log <log_type> - Display logs for a specified directory and log type."
	@echo "  make clean 	      - Clean up generated files in a specified directory."

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
.PHONY: default check run log clean $(runargs) $(logargs)


##################################################
# Target: check
# This target checks Verilog design files in a specified directory.
# Usage:
#   make check
##################################################
check:
	@ cd Scripts && python3 execute_tests.py -c


##################################################
# Target: run
# This target runs tests with the specified arguments:
# - <mode>: Test mode (default or one of `v`, `g`, `s`, `c`).
# - <a>: Optional flag for additional arguments (e.g., 'a' to run all tests in a specific mode).
# Usage:
#   make run <mode> [a]
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
		if [ "$(words $(runargs))" -eq 2 ] && [ "$(word 2, $(runargs))" == "a" ]; then \
			cd Scripts && python3 execute_tests.py -m $$mode -a; \
		else \
			cd Scripts && python3 execute_tests.py -m $$mode; \
		fi; \
	# If arguments are invalid or incomplete, print an error and usage. \
	else \
		echo "Error: Invalid arguments for 'run' target. Usage:"; \
		echo "  make run v|g|s|c [a]"; \
		exit 1; \
	fi;


##################################################
# Target: log
# This target displays logs based on the provided log mode:
# - <log_type>: Type of log (either `c` for compilation logs or `t` for transcript logs).
# Usage:
#   make log <log_type>
##################################################
log:
	@if [ "$(words $(logargs))" -eq 1 ]; then \
		case "$(word 1, $(logargs))" in \
			c) \
				cd Scripts && python3 execute_tests.py -l c; \
				;; \
			t) \
				cd Scripts && python3 execute_tests.py -l t; \
				;; \
			*) \
				echo "Error: Invalid log mode. Supported modes are c (compilation) or t (transcript)."; \
				exit 1; \
				;; \
		esac; \
	# If the arguments are invalid or incomplete, print an error. \
	else \
		echo "Error: Missing or invalid arguments for 'log' target. Usage:"; \
		echo "  make log c|t"; \
		exit 1; \
	fi;


##################################################
# Target: clean
# This target cleans up generated files in a specified directory:
# Usage:
#   make clean
##################################################
clean:
	@echo "Available directories to clean:"; \
	# List the top-level directories in the current directory. \
	top_level_dirs=$$(ls -d */ | grep -E 'Phase-1|Phase-2|Phase-3'); \
	if [ -z "$$top_level_dirs" ]; then \
		echo "No valid top-level directories (Phase-1, Phase-2, Phase-3) found."; \
		exit 1; \
	fi; \
	PS3="Please select a top-level directory (Phase-1, Phase-2, Phase-3) to clean from: "; \
	select top_level_dir in $$top_level_dirs; do \
		if [ -n "$$top_level_dir" ] && [ -d "$$top_level_dir" ]; then \
			break; \
		else \
			echo "Invalid selection, please choose a valid top-level directory."; \
		fi; \
	done; \
	# Now using $$top_level_dir in the next part within the same shell invocation \
	echo "Available subdirectories in $$top_level_dir to clean:"; \
	# Correctly list the subdirectories within the selected top-level directory \
	subdirs=$$(find "$$top_level_dir" -mindepth 1 -maxdepth 1 -type d); \
	if [ -z "$$subdirs" ]; then \
		echo "No subdirectories found to clean in $$top_level_dir."; \
		exit 1; \
	fi; \
	PS3="Please select a subdirectory to clean: "; \
	select subdir in $$subdirs; do \
		if [ -n "$$subdir" ] && [ -d "$$subdir" ]; then \
			echo "You selected $$subdir"; \
			echo "Cleaning up generated files in directory $$subdir..."; \
			rm -rf "$$subdir/output/" "$$subdir/work/"; \
			echo "Cleanup complete."; \
			break; \
		else \
			echo "Invalid selection, please choose a valid subdirectory."; \
		fi; \
	done