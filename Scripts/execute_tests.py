import os
import re
import sys
import argparse
import subprocess
from pathlib import Path
import concurrent.futures

# Constants for directory paths.
ROOT_DIR = os.path.abspath("..")
SCRIPTS_DIR = os.path.join(ROOT_DIR, "Scripts")
PHASE1_DIR = os.path.join(ROOT_DIR, "Phase-1")
PHASE2_DIR = os.path.join(ROOT_DIR, "Phase-2")       
PHASE3_DIR = os.path.join(ROOT_DIR, "Phase-3")         
TEST_PROGRAMS_DIR = os.path.join(ROOT_DIR, "TestPrograms")

TEST_DIR = None
TESTS_DIR = None
DESIGNS_DIR = None
TEST_FILE = None
OUTPUTS_DIR = None

WAVE_CMD_DIR = None
OUTPUT_DIR = None
WAVES_DIR = None
LOGS_DIR = None
TRANSCRIPT_DIR = None
COMPILATION_DIR = None
WORK_DIR = None


def parse_arguments():
    """
    Parse and validate command-line arguments for running a testbench.

    This function defines the arguments available for the script, validates them, 
    and ensures that the appropriate flags are used based on the desired functionality. 
    The function also provides clear error handling for missing or incompatible arguments.

    Arguments:
        - The '-m' flag is optional and specifies the mode for running tests:
            0=Command-line, 1=Save waves, 2=GUI, 3=View saved waves.
        - The '-a' flag allows running all testbenches in the specified directory.
        - The '-c' flag enables design file checking for compliancy in the specified directory.
        - The '-l' flag enables the selection of logs to display: 't' for transcript and 'c' for compilation.

    Returns:
        argparse.Namespace: A namespace object containing the parsed arguments.

    Raises:
        SystemExit: If required arguments are missing or incompatible, the function will exit with an error message.
    """
    parser = argparse.ArgumentParser(description="Run a testbench in various modes.")

    # Optional argument for specifying the mode of running tests.
    parser.add_argument(
        "-m", "--mode", type=int, choices=[0, 1, 2, 3], default=0,
        help="Test execution mode: 0=Command-line, 1=Save waves, 2=GUI, 3=View saved waves."
    )

    # Flag to indicate whether to run all testbenches in the directory.
    parser.add_argument("-a", "--all", action="store_true", help="Run all testbenches in the directory.")

    # Flag to assemble a file and output the image file in the tests directory.
    parser.add_argument("-as", "--asm", action="store_true", help="Assemble a file and output the image file in the test directory.")

    # Option to check all verilog files within a directory.
    parser.add_argument("-c", "--check", action="store_true", help="Check all Verilog design files in the directory.")

    # Option to select which type of log to display.
    parser.add_argument("-l", "--logs", type=str, choices=["t", "c"], help="Display logs: 't' for transcript, 'c' for compilation.")

    # Parse and return the arguments.
    return parser.parse_args()


def choose_directory(args):
    """
    List valid directories in the current directory (Phase-1, Phase-2, Phase-3) and prompt the user to choose one.

    Args:
        args (Namespace): Parsed command-line arguments for determining the context of directory usage.

    Returns:
        str: The selected subdirectory's path.
    """
    # Define the top-level valid directories
    top_level_dirs = [PHASE1_DIR, PHASE2_DIR, PHASE3_DIR]

    # Determine the prompt message based on the args flags
    if args.logs == "c":
        prompt_message = "Enter the number of the directory to view compilation logs: "
    elif args.check:
        prompt_message = "Enter the number of the directory to check Verilog design files: "
    elif args.logs == "t":
        prompt_message = "Enter the number of the directory to view transcript logs: "
    elif args.mode == 3:
        prompt_message = "Enter the number of the directory to view waveforms: "
    else:
        prompt_message = "Enter the number of the directory to run tests: "

    # Display the prompt message after the top-level directory is selected but before subdirectory selection
    print(prompt_message)

    # Prompt the user to choose one of the top-level directories
    for idx, directory in enumerate(top_level_dirs, 1):
        print(f"{idx}. {os.path.basename(directory)}")

    while True:
        try:
            selection = int(input("Enter the number of the directory to choose: "))
            if 1 <= selection <= len(top_level_dirs):
                selected_top_dir = top_level_dirs[selection - 1]
                break
            else:
                print(f"Invalid input. Please enter a number between 1 and {len(top_level_dirs)}.")
        except ValueError:
            print("Invalid input. Please enter a valid number.")

    # Return the selected directory path
    return selected_top_dir


def setup_directories(name):
    """
    Ensure necessary directories exist for output, logs, and waveforms, and set up the environment.

    This function creates all required directories, such as the output, logs, and waveform directories. 
    If the directories already exist, they are not recreated. The function also validates that the 
    specified test directory exists before proceeding.

    Args:
        name (str): The name of the testbench directory to set up, typically corresponding to a test.

    Raises:
        FileNotFoundError: If the specified test directory does not exist.
        OSError: If there is an error while creating the required directories.

    Returns:
        None: This function does not return any value. It only ensures that the directories are set up 
              and ready for use.
    """
    # Modifying the global directory variables declared above.
    global TEST_DIR, OUTPUTS_DIR, TESTS_DIR, DESIGNS_DIR, TEST_PROGRAMS_DIR, WAVE_CMD_DIR, OUTPUT_DIR, WAVES_DIR, LOGS_DIR, TRANSCRIPT_DIR, COMPILATION_DIR, WORK_DIR

    # Set the path for the main test directory using the provided 'name'.
    TEST_DIR = os.path.join(ROOT_DIR, name)

    # Set the path for the outputs directory.
    OUTPUTS_DIR = os.path.join(TEST_DIR, "outputs")

    # Set the path for the directory containing design files.
    DESIGNS_DIR = os.path.join(TEST_DIR, "designs")

    # Set the path for the directory containing testbench files.
    TESTS_DIR = os.path.join(TEST_DIR, "tests")

    # Verify that the provided test directory exists.
    if not os.path.exists(TEST_DIR):
        # If not, raise a FileNotFoundError.
        raise FileNotFoundError(f"Directory '{name}' does not exist.")

    # Define the paths for directories that depend on the test directory (TEST_DIR).
    WAVE_CMD_DIR = os.path.join(TESTS_DIR, "add_wave_commands")  # Directory for waveform command files.
    OUTPUT_DIR = os.path.join(TESTS_DIR, "output")       # Output directory for the test results.
    WAVES_DIR = os.path.join(OUTPUT_DIR, "waves")       # Directory for waveform files.
    LOGS_DIR = os.path.join(OUTPUT_DIR, "logs")         # Directory for log files.
    TRANSCRIPT_DIR = os.path.join(LOGS_DIR, "transcript")  # Directory for transcript logs.
    COMPILATION_DIR = os.path.join(LOGS_DIR, "compilation")  # Directory for compilation logs.
    WORK_DIR = os.path.join(TESTS_DIR, "WORK")           # Directory for temporary work files.

    # Ensure that all the necessary directories are created, if they do not exist.
    directories = [WAVE_CMD_DIR, OUTPUT_DIR, WAVES_DIR, LOGS_DIR, TRANSCRIPT_DIR, COMPILATION_DIR, WORK_DIR]
    for directory in directories:
        # 'mkdir' ensures that the directory and any necessary parent directories are created.
        # 'exist_ok=True' prevents an error if the directory already exists.
        Path(directory).mkdir(parents=True, exist_ok=True)
    
    # Change the current working directory to the test directory to execute the tests.
    os.chdir(TEST_DIR)


def list_log_files(log_type):
    """
    List the available log files for a given type of log.

    This function checks the specified log directory (either transcript or compilation) 
    and returns a list of log files with the ".log" extension.

    Args:
        log_type (str): The type of log to retrieve files for. Can be 't' for transcript or 'c' for compilation.

    Returns:
        list: A list of available log files matching the specified type. If no logs are found, an empty list is returned.
    """
    log_dir = TRANSCRIPT_DIR if log_type == "t" else COMPILATION_DIR

    # Return an empty list if the directory doesn't exist.
    if not os.path.exists(log_dir):
        return []

    # List all files in the log directory that end with ".log".
    return [
        file
        for file in os.listdir(log_dir)
        if file.endswith(".log")
    ]


def display_log(log_type):
    """
    Display the contents of a log file based on the specified type.

    If there is exactly one log file available, the function will display that file automatically.
    If multiple log files are available, the user will be prompted to select one.

    Args:
        log_type (str): Type of log to display, either 't' for transcript or 'c' for compilation.

    Raises:
        FileNotFoundError: If no log files are available in the specified directory.
    """
    # Determine the appropriate log directory based on the log type.
    log_dir = TRANSCRIPT_DIR if log_type == "t" else COMPILATION_DIR

    # Get a list of available logs for the specified log type.
    available_logs = list_log_files(log_type)

    # If no logs are found, inform the user and exit.
    if not available_logs:
        if log_type == "t":
            print(f"No transcript log files found in {log_dir}.")
        else:
            print(f"No compilation log files found in {log_dir}.")
        return

    # If there is only one log file, display it directly without prompting for selection.
    if len(available_logs) == 1:
        log_file = os.path.join(log_dir, available_logs[0])
        with open(log_file, "r") as file:
            print(f"=== Displaying {available_logs[0]} ===")
            print(file.read())
        return

    # Display the available log files to the user if there are multiple.
    print(f"Available {log_type.upper()} logs:")
    for idx, log_file in enumerate(available_logs):
        print(f"{idx + 1}: {log_file}")

    # Prompt the user to select a log file.
    while True:
        try:
            selection = int(input(f"Enter the number of the log file to display (1-{len(available_logs)}): "))
            
            # Check if the input is a valid selection.
            if 1 <= selection <= len(available_logs):
                log_file = os.path.join(log_dir, available_logs[selection - 1])
                
                # Open and display the selected log file's content.
                with open(log_file, "r") as file:
                    print(f"=== Displaying {available_logs[selection - 1]} ===")
                    print(file.read())
                break
            else:
                print(f"Invalid input. Please enter a number between 1 and {len(available_logs)}.")
        except ValueError:
            print("Invalid input. Please enter a valid number.")
        except FileNotFoundError:
            print(f"Log file not found: {log_file}")

    # Exit the program after displaying the log file.
    sys.exit(0)


def check_design_files():
    """
    Checks Verilog design files in the current directory, excluding testbench files (_tb.v).
    Runs the 'java Vcheck <design_file.v>' command on each file and reports any errors.

    This function:
    - Scans the current directory for Verilog design files (.v).
    - Excludes testbench files (_tb.v).
    - Runs the Vcheck tool on each file and captures the output.
    - Prints error messages for any design files that fail the check.
    - Prints a success message if all design files are compliant.
    
    Returns:
        None
    """
    # Change the directory to the designs folder.
    os.chdir(DESIGNS_DIR)

    # Get absolute paths of all Verilog files (excluding testbench files).
    verilog_files = [os.path.abspath(f) for f in os.listdir()]
    
    # List to store files that fail the check.
    failed_files = []

    # Iterate over each design file and run the Vcheck command.
    for vfile in verilog_files:
        try:
            # Run 'java Vcheck <design_file.v>' with the specified classpath
            result = subprocess.run(
                f"java -cp {SCRIPTS_DIR} Vcheck {vfile}",  # Command to execute
                shell=True,                                # Execute in a shell
                stdout=subprocess.PIPE,                    # Capture standard output
                stderr=subprocess.PIPE,                    # Capture standard error
                check=True                                 # Raise exception on non-zero exit code
            )
            
            # Decode the output (result.stdout is in bytes)
            output = result.stdout.decode('utf-8').strip()  # Convert to string and remove leading/trailing whitespace
            
            # If the output does NOT start with "End of file", it indicates a failure
            if not output.startswith("End of file"):
                failed_files.append((vfile, output))  # Store failed file and error message
        
        except subprocess.CalledProcessError as e:
            # Handle the exception if the command fails
            print(f"===== Error running Vcheck on {os.path.basename(vfile)} =====")
            # Decode and clean the error message from stderr.
            error_message = e.stderr.decode('utf-8').replace("\n", " ").strip()  # Remove internal newlines
            print(f"{error_message}")
            sys.exit(1)  # Exit if there's an error running Vcheck

    # Print results
    if failed_files:
        # If there are failing files, print their errors
        print("The following design files are not compliant:\n")
        for vfile, error in failed_files:
            print(f"Check failed for {os.path.basename(vfile)}:\n{error}\n")
    else:
        # If no files failed, print success message.
        if len(verilog_files) != 0:
            print("YAHOO!! All Verilog design files are compliant.")
        else:
        # Exit gracefully, if no Verilog design files found.
            print(f"No Verilog design files found in {os.path.basename(DESIGNS_DIR)}. Exiting...")


def assemble():
    """
    Lists all WISC-S25 assembly files in the TestPrograms directory, prompts the user to select one, 
    and then runs `perl ./Scripts/assembler.pl <infile> > TESTS_DIR/instructions.img` to assemble it.

    The function ensures the TESTS_DIR exists, provides an interactive selection for the user, 
    and executes the assembler script with error handling.

    Raises:
        SystemExit: If no assembly files are found or if the assembly process fails.
    """
    # Set the input file as the test file chosen
    global TEST_FILE

    # Retrieve all valid assembly files in the directory
    asm_files = [f for f in os.listdir(TEST_PROGRAMS_DIR) if f.endswith(".s") or f.endswith(".list")]

    # If no assembly files are found, notify the user and exit
    if not asm_files:
        print(f"No WISC-S25 assembly files found in {os.path.basename(TEST_PROGRAMS_DIR)}. Exiting...")
        sys.exit(1)

    # Display the available assembly files as a numbered list
    print("Available WISC-S25 Assembly Files:")
    for idx, file in enumerate(asm_files, start=1):
        print(f"{idx}. {file}")

    # Prompt the user to select an assembly file
    while True:
        try:
            choice = int(input("Select a file to assemble (enter number): ")) - 1
            if 0 <= choice < len(asm_files):
                break  # Valid choice, exit loop
            else:
                print("Invalid selection. Please enter a valid number.")
        except ValueError:
            print("Invalid input. Please enter a number.")

    # Get the full path of the selected input file.
    infile = os.path.join(TEST_PROGRAMS_DIR, asm_files[choice])
    outfile = os.path.join(TESTS_DIR, "instructions.img") 

    # Construct the command to run the assembler.
    command = f"perl {SCRIPTS_DIR}/assembler.pl {infile} > {outfile}"

    # Execute the assembler command with error handling.
    try:
        result = subprocess.run(
            command,
            shell=True,                                # Execute in a shell
            stdout=subprocess.PIPE,                    # Capture standard output
            stderr=subprocess.PIPE,                    # Capture standard error
            check=True                                 # Raise exception on non-zero exit code
        )
    except subprocess.CalledProcessError as e:
        print(f"\n===== Error assembling file {os.path.basename(infile)} =====")
        # Decode and format the error message from stderr
        error_message = e.stderr.decode('utf-8').replace("\n", " ").strip()
        print(f"{error_message}")
        sys.exit(1)  # Exit the script with an error code
    
    # Set the infile for use.
    TEST_FILE = os.path.splitext(os.path.basename(infile))[0]


def check_logs(logfile, mode):
    """
    Check the status of a log file based on the specified mode.

    Args:
        logfile (str): Path to the log file that contains simulation or compilation output.
        mode (str): Mode of checking. Use:
            - "t" for checking simulation transcript logs.
            - "c" for checking compilation logs.

    Returns:
        str: The result of the log check, which could be one of the following:
            - "success": No issues found.
            - "error": Issues detected in the log.
            - "warning": Warnings found in the log.
            - "unknown": Status could not be determined (specific to transcript logs).

    Description:
        - Based on the mode, the function delegates to either `check_transcript` for simulation logs
          or `check_compilation` for compilation logs.
        - It analyzes the content of the log file to detect errors, warnings, or successes.
    """
    
    def check_compilation(log_file):
        """
        Check the compilation log for errors or warnings.

        Args:
            log_file (str): Path to the compilation log file.

        Returns:
            str: Returns one of the following:
                - "error": If any errors are found.
                - "warning": If warnings are present.
                - "success": If no issues are found in the compilation log.
                
        Description:
            - Reads the content of the compilation log file to check for "Error:" or "Warning:" keywords.
            - Returns the status based on the presence of these keywords.
        """
        # Open and read the content of the log file
        with open(log_file, "r") as file:
            content = file.read()

            # Check for the presence of "Error:" or "Warning:" keywords
            if "Error:" in content:
                return "error"
            elif "Warning:" in content:
                return "warning"
            else:
                return "success"

    def check_transcript(log_file):
        """
        Check the simulation transcript for success or failure.

        Args:
            log_file (str): Path to the simulation transcript log file.

        Returns:
            str: Returns one of the following:
                - "success": If the test passed successfully.
                - "error": If an error occurred during the simulation.
                - "warning": If there were warnings in the simulation.
                - "unknown": If the status could not be determined from the transcript.
                
        Description:
            - Reads the simulation transcript log file to look for specific success or failure keywords.
            - Checks for the presence of "ERROR" (for failure), "YAHOO!! All tests passed." (for success),
              or "Warning:" (for warnings).
        """
        # Open and read the content of the transcript log file
        with open(log_file, "r") as file:
            content = file.read()

            # Check for specific success or failure strings in the transcript
            if any(word in content for word in ["ERROR", "FAIL"]):
                return "error"
            elif any(word in content for word in ["YAHOO!!", "YIPPEE"]):
                return "success"
            elif "Warning:" in content:
                return "warning"
            else:
                return "unknown"

    # Direct to the appropriate check function based on the mode
    if mode == "t":
        return check_transcript(logfile)
    elif mode == "c":
        return check_compilation(logfile)


def get_files_to_compile(all_files, log_file):
    """
    Determine which .v files need recompilation based on the existence and 
    timestamps of the compilation log file and the source .v files.

    Args:
        all_files (list): A list of all .v files to be considered for compilation.
        log_file (str): Path to the compilation log file.

    Returns:
        str: A space-separated string of .v files that need recompilation.
    """
    # Initialize a string to store the .v files that require recompilation.
    files_to_recompile = ""

    # Check if the log file exists or if it contains errors.
    if not os.path.exists(log_file) or check_logs(log_file, "c") == "error":
        # If the log file doesn't exist or has errors, mark all files for recompilation.
        for v_file in all_files:
            files_to_recompile += v_file + " "  # Append file to the list with a space separator.
        
        return files_to_recompile  # Return all files for recompilation.

    # Get the modification timestamp of the log file.
    log_file_mtime = os.path.getmtime(log_file)

    # Compare the modification time of each .v file to the log file's timestamp.
    for v_file in all_files:
        if os.path.getmtime(v_file) > log_file_mtime:
            # If the .v file is newer than the log file, mark it for recompilation.
            files_to_recompile += v_file + " "

    return files_to_recompile  # Return the list of files needing recompilation.


def compile_files(test_name, dependencies, args):
    """
    Compile the required files for the test simulation.

    This function checks if recompilation is needed by calling `get_files_to_compile`.
    If no recompilation is needed, it exits without performing compilation.

    Args:
        test_name (str): The name of the testbench file to be compiled.
        dependencies (list): List of all .v sub-files as dependencies along with the `_tb.v` file to be considered for compilation.
        args (argparse.Namespace): Command-line arguments, including flags to modify behavior.

    Raises:
        SystemExit: If compilation fails, the program exits with an error.
    """
    # Path to the compilation log file.
    log_file = os.path.join(COMPILATION_DIR, f"{test_name}_compilation.log")

    # Determine the files that need recompilation.
    files_to_compile = get_files_to_compile(dependencies, log_file)

    # If no files need recompilation, exit without performing compilation.
    if not files_to_compile:
        return
    
    try:
        # Check if the work library exists, and compile accordingly.
        if not Path(f"./tests/WORK/{test_name}").is_dir():
            compile_command = (
                f"vsim -c -logfile {log_file} -do "
                f"'vlib ./tests/WORK/{test_name}; vlog +acc -work ./tests/WORK/{test_name} -stats=none {files_to_compile}; quit -f;'"
            )
        else:
            compile_command = (
                f"vlog +acc -logfile {log_file} -work ./tests/WORK/{test_name} -stats=none {files_to_compile}"
            )
        subprocess.run(compile_command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    except subprocess.CalledProcessError as e:
        if args.all:
            print(f"{test_name}: Compilation failed with error {e.returncode}. Run 'make log c' for details. {e.stderr.decode('utf-8')}.")
        else:
            # Print log file contents in case of an error when running a single test.
            with open(log_file, 'r') as log_fh:
                print("\n===== Compilation failed with the following errors =====\n")
                print(log_fh.read())
        sys.exit(1)
    

    # Check the log file for warnings or errors.
    result = check_logs(log_file, "c")
    if result == "warning":
        print(f"{test_name}: Compilation completed with warnings. Run 'make log c' for details.")
    elif result == "error":
        if args.all:
            print(f"{test_name}: Compilation has errors. Run 'make log c' for details.")
        else:
            # Print log file contents in case of an error when running a single test.
            with open(log_file, 'r') as log_fh:
                print("\n===== Compilation failed with the following errors =====\n")
                print(log_fh.read())
        sys.exit(1)


def find_dependencies(dep_file, resolved_files=None, module_definitions=None, package_definitions=None):
    """
    Recursively finds all module and package dependencies for a given SystemVerilog testbench file.

    - Modules are only searched in DESIGNS_DIR.
    - Testbenches and packages are only searched in TESTS_DIR.
    
    Args:
        dep_file (str): Path to the SystemVerilog testbench file for which dependencies are to be resolved.
        resolved_files (list, optional): List to store the resolved dependencies in compilation order. 
                                         Defaults to None, in which case a new list is created.
        module_definitions (dict, optional): Precomputed mapping of module names to file paths. 
                                             If None, the map is built during execution.
        package_definitions (dict, optional): Precomputed mapping of package names to file paths. 
                                              If None, the map is built during execution.

    Returns:
        list: A list of file paths in the correct order for compilation, with the top-level testbench file first.
    """
    # Initialize resolved files list
    if resolved_files is None:
        resolved_files = []
    if dep_file not in resolved_files:
        resolved_files.append(dep_file)  # Keep insertion order

    # Build module and package definitions if not provided
    if module_definitions is None or package_definitions is None:
        module_definitions = {}
        package_definitions = {}

        # Regular expressions for finding module and package definitions
        module_def_pattern = re.compile(r'^\s*module\s+(\w+)', re.MULTILINE)
        package_def_pattern = re.compile(r'^\s*package\s+(\w+)', re.MULTILINE)

        # Scan only DESIGN_DIR for .v module definitions
        for root, _, files in os.walk(DESIGNS_DIR):
            for file in files:
                if file.endswith('.v'):
                    file_path = os.path.join(root, file)
                    with open(file_path, 'r') as f:
                        content = f.read()
                        for match in module_def_pattern.finditer(content):
                            module_name = match.group(1)
                            module_definitions[module_name] = file_path

        # Scan only TESTS_DIR for .sv package definitions
        for root, _, files in os.walk(TESTS_DIR):
            for file in files:
                if file.endswith('.sv'):  
                    file_path = os.path.join(root, file)
                    with open(file_path, 'r') as f:
                        content = f.read()
                        for match in package_def_pattern.finditer(content):
                            package_name = match.group(1)
                            package_definitions[package_name] = file_path

    # Regular expressions for identifying dependencies
    module_inst_pattern = re.compile(r'^\s*(\w+)\s*(#\([^)]*\))?\s+\w+\s*(\[\d+:\d+\])?\s*\(.*?\);', re.DOTALL | re.MULTILINE)
    import_pattern = re.compile(r'^\s*import\s+(\w+)\s*::\*;', re.MULTILINE)

    # Read the testbench file to extract dependencies
    with open(dep_file, 'r') as v_file:
        v_file_content = v_file.read()

    dependencies = set()
    dependencies.update(match.group(1) for match in module_inst_pattern.finditer(v_file_content))  # Modules
    dependencies.update(match.group(1) for match in import_pattern.finditer(v_file_content))  # Packages

    # Resolve dependencies recursively
    for dep in dependencies:
        if dep in module_definitions:
            dep_file = module_definitions[dep]
            if dep_file not in resolved_files:
                resolved_files.insert(0, dep_file) 
                find_dependencies(dep_file, resolved_files, module_definitions, package_definitions)
        elif dep in package_definitions:
            dep_file = package_definitions[dep]
            if dep_file not in resolved_files:
                resolved_files.append(0, dep_file)
                find_dependencies(dep_file, resolved_files, module_definitions, package_definitions)

    return resolved_files


def find_signals(signal_names, test_name):
    """
    Find the full hierarchy paths for the given signal names.

    This function uses the ModelSim/QuestaSim `vsim` command to search for signals in the design hierarchy.
    If a full path is provided for a signal, it is directly added to the result.
    Otherwise, the function searches for signals matching the provided name and resolves their full paths.

    Args:
        signal_names (list of str): List of signal names to search for. Full paths or partial names are accepted.
        test_name (str): The test name used to determine the required signals.

    Returns:
        list of str: A list of full hierarchy paths for the provided signals. If a signal cannot be resolved,
                     it is not included in the returned list.

    Raises:
        subprocess.CalledProcessError: If the `vsim` command fails during execution.
    """
    # List to store resolved signal paths.
    signal_paths = []

    for signal in signal_names:
        # If the signal name already includes a full path, add it directly to the list.
        if "/" in signal:
            signal_paths.append(signal)
            continue

        try:
            # Run the vsim command to search for signals matching the provided name.
            result = subprocess.run(
                f"vsim -c ./tests/WORK/{test_name}.{test_name} -do 'find signals /{test_name}/{signal}* -recursive; quit -f;'",
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )

            # Flag to indicate if the signal was found.
            found_signal = False 

            # Process the vsim output to extract signal paths.
            for part in result.stdout.split():
                # Skip irrelevant lines and comments in the vsim output.
                if part.startswith("#") or not part.strip() or part.strip() in ["//", "-access/-debug"]:
                    continue

                # Check if the output line contains a valid path
                if "/" in part:
                    # Match the last component of the path with the signal name
                    if part.strip().split("/")[-1] == signal and not found_signal:
                        signal_paths.append(part.strip())
                        found_signal = True  # Avoid duplicate entries for the same signal.
        except subprocess.CalledProcessError as e:
            # Handle errors from the vsim command and provide feedback.
            print(f"{test_name}: Error finding signal {signal}: {e.stderr.decode('utf-8')}")
            sys.exit(1)

    return signal_paths


def get_wave_command(test_name, args):
    """
    Generate or retrieve the waveform command for a given testbench.

    Args:
        test_name (str): The name of the testbench, used to locate or generate signal wave commands.
        args (argparse.Namespace): Command-line arguments, including flags to modify behavior.

    Returns:
        str: A single-line string of waveform commands for the selected signals.

    Description:
        - Checks if a waveform command file already exists for the testbench.
        - Prompts the user to confirm using the existing commands or to provide new signals.
        - Locates full signal paths and generates a `wave_command.txt` file if necessary.
        - Returns the waveform command string for simulation.
    """
    # Define the wave command file path.
    wave_command_file = os.path.join(WAVE_CMD_DIR, f"{test_name}_wave_command.txt")

    # Check if the wave command file exists.
    if os.path.exists(wave_command_file):
        # Read the existing wave command from the file.
        with open(wave_command_file, "r") as file:
            add_wave_command = file.read().strip()

        if not args.all:
            print(f"{test_name}: Wave command file already exists.")
            user_choice = input("Would you like to use the existing signals? (y/n): ").strip().lower()

            if user_choice == "y":
                return add_wave_command
        else:
            return add_wave_command

    # Prompt the user for new signals if no file exists or they choose to modify.
    print(f"{test_name}: Please enter the signals to add (comma-separated):")
    user_input = input("Signals: ")

    # Parse the user input into a list of signals.
    signals_to_use = [signal.strip() for signal in user_input.split(",") if signal.strip()]

    # Find full hierarchy paths for the selected signals.
    signal_paths = find_signals(signals_to_use, test_name)

    if not signal_paths:
        print(f"{test_name}: No signals found. Exiting...")
        sys.exit(1)

    # Generate a single-line waveform command.
    add_wave_command = " ".join([f"add wave {signal};" for signal in signal_paths])

    # Save the command to a file.
    with open(wave_command_file, "w") as file:
        file.write(add_wave_command)

    return add_wave_command


def get_gui_command(test_name, log_file, args):
    """
    Generate the simulation command for GUI-based waveform viewing.

    Args:
        test_name (str): The name of the testbench, used to locate waveform files.
        log_file (str): Path to the log file for saving simulation output.
        args (argparse.Namespace): Command-line arguments, including simulation mode.

    Returns:
        str: The complete simulation command string for GUI-based waveform generation.

    Description:
        - Constructs a GUI simulation command with flags to generate waveforms.
        - Retrieves or generates waveform commands for signals.
        - Adds options to save waveform formats and logs.
        - Adjusts command to quit after simulation based on the mode.
    """
    # Define paths for waveform files.
    wave_file = os.path.join(WAVES_DIR, f"{test_name}.wlf")
    wave_format_file = os.path.join(WAVES_DIR, f"{test_name}.do")

    # Get the waveform commands for signal addition.
    add_wave_command = get_wave_command(test_name, args)

    # Construct the base simulation command.
    sim_command = (
        f"vsim -wlf {wave_file} ./tests/WORK/{test_name}.{test_name} -logfile {log_file} -voptargs='+acc' "
        f"-do '{add_wave_command} run -all; write format wave -window .main_pane.wave.interior.cs.body.pw.wf {wave_format_file}; log -flush /*;'"
    )

    # Ensure the simulation quits after completion for certain modes.
    if args.mode in (0, 1):
        sim_command = sim_command[:-1] + " quit -f;'"

    return sim_command


def run_simulation(test_name, log_file, args):
    """
    Run the simulation for a specific testbench based on the selected mode.

    Args:
        test_name (str): The name of the testbench, excluding the `.v` extension.
        log_file (str): Path to the log file for saving simulation output.
        args (argparse.Namespace): Command-line arguments, including the simulation mode.

    Returns:
        str: The result of the simulation ("success", "error", "warning", or "unknown").

    Description:
        - Mode 0: Command-line simulation without GUI.
        - Mode 1: GUI simulation with waveform saving.
        - Mode 2: Full GUI mode for debugging.
        - Constructs the appropriate simulation command and executes it.
        - Logs simulation output and returns the status based on log file checks.
    """
    # Define paths for the wave file.
    wave_file = os.path.join(WAVES_DIR, f"{test_name}.wlf")

    if args.mode == 0:
        if not args.all:
            print(f"{test_name}: Running in command-line mode...")
        sim_command = f"vsim -c ./tests/WORK/{test_name}.{test_name} -wlf {wave_file} -logfile {log_file} -do 'run -all; log -flush /*; quit -f;'"
    else:
        if args.mode == 1:
            if not args.all:
                print(f"{test_name}: Saving waveforms and logging to file...")
        elif args.mode == 2:
            if not args.all:
                print(f"{test_name}: Running in GUI mode...")

        sim_command = get_gui_command(test_name, log_file, args)

    # Execute the simulation command.
    with open(log_file, 'w') as log_fh:
        try:
            subprocess.run(sim_command, shell=True, stdout=log_fh, stderr=subprocess.PIPE, check=True)
        except subprocess.CalledProcessError as e:
            if args.all:
                print(f"{test_name}: Running test failed with error {e.returncode}. Run 'make log t' for details. {e.stderr.decode('utf-8')}")
            else:
                # Print log file contents in case of an error when running a single test.
                with open(log_file, 'r') as log_fh:
                    print(f"\n===== Running {test_name} failed with the following errors =====\n")
                    print(log_fh.read())
            sys.exit(1)
    
    # Rename simulation files if applicable.
    rename_sim_files()

    return check_logs(log_file, "t")


def rename_sim_files():
    """
    Renames the 'verilogsim.trace' and 'verilogsim.log' files by appending the base name 
    of the input file.

    Returns:
        None: Renames the files in place.
    """
    # Define paths for the simuation files.
    trace_file = os.path.join(OUTPUTS_DIR, f"verilogsim.trace")
    log_file = os.path.join(OUTPUTS_DIR, f"verilogsim.log")

    # Create new file names by appending the base name.
    new_trace_file = os.path.join(OUTPUTS_DIR, f"{TEST_FILE}_verilogsim.trace.txt")
    new_log_file = os.path.join(OUTPUTS_DIR, f"{TEST_FILE}_verilogsim.log.txt")

    # Rename the trace file if it exists.
    if os.path.exists(trace_file):
        os.rename(trace_file, new_trace_file)

    # Rename the log file if it exists.
    if os.path.exists(log_file):
        os.rename(log_file, new_log_file)


def run_test(test_name, args):
    """
    Run a specific testbench by compiling and executing the simulation.

    Args:
        test_name (str): The name of the testbench, excluding the `.v` extension.
        args (argparse.Namespace): Command-line arguments, including simulation mode.

    Returns:
        None: Prints the test result status to the console.

    Description:
        - Executes the simulation using `run_simulation`.
        - Handles various results ("success", "error", "warning", "unknown").
        - For failures, provides debugging options and logs output.
    """
    log_file = os.path.join(TRANSCRIPT_DIR, f"{test_name}_transcript.log")

    # Run the simulation and get the result.
    result = run_simulation(test_name, log_file, args)

    # Output the test result based on the status.
    if result == "success":
        print(f"{test_name}: YAHOO!! All tests passed.")
    elif result == "error":
        if args.mode == 0:
            if args.all:
                print(f"{test_name}: Test failed. Run 'make log t' for details. Saving waveforms for later debug...")
            else:
                # Print log file contents in case of an error when running a single test.
                with open(log_file, 'r') as log_fh:
                    print(f"\n===== Running {test_name} failed with the following errors =====\n")
                    print(log_fh.read())
                    print(f"{test_name}: Saving waveforms for later debug...")

            debug_command = get_gui_command(test_name, log_file, args)
            with open(log_file, 'w') as log_fh:
                try:
                    subprocess.run(debug_command, shell=True, stdout=log_fh, stderr=subprocess.PIPE, check=True)
                except subprocess.CalledProcessError as e:
                    if args.all:
                        print(f"{test_name}: Running test failed with error {e.returncode}. Run 'make log t' for details. {e.stderr.decode('utf-8')}")
                    else:
                        # Print log file contents in case of an error when running a single test.
                        with open(log_file, 'r') as log_fh:
                            print(f"\n===== Running {test_name} failed with the following errors =====\n")
                            print(log_fh.read())
                    sys.exit(1)
        elif args.mode == 1:
            print(f"{test_name}: Test failed. Run 'make log t' for details.")
    elif result == "warning":
        print(f"{test_name}: Test completed with warnings. Run 'make log t' for details.")
    elif result == "unknown":
        print(f"{test_name}: Unknown status. Run 'make log t' for details.")


def view_waveforms(test_name, args):
    """
    View previously saved waveforms for a specific testbench.

    Args:
        test_name (str): The name of the testbench, excluding the `.v` extension.
                         Used to locate the corresponding waveform and simulation files.
        args (argparse.Namespace): Command-line arguments containing the `all` flag to 
                                    determine if messages should be printed for individual tests.

    Returns:
        None: This function does not return a value but executes a simulator command to 
              view the saved waveforms for the specified testbench.

    Description:
        - Changes the current directory to the waveform directory (`WAVES_DIR`).
        - Opens a transcript file specific to the testbench to log output.
        - Constructs and executes a simulator command to load the saved waveform (`.wlf`)
          and associated script (`.do` file).
        - Handles errors gracefully if the simulation command fails, providing feedback
          to the user and exiting with an appropriate error code.
    """
    # Change to the waveforms directory to access saved waveform files.
    os.chdir(WAVES_DIR)

    # View the saved waveforms by invoking the simulator.
    with open(f"{test_name}_transcript", 'w') as transcript:
        if not args.all:
            print(f"{test_name}: Viewing saved waveforms...")
        sim_command = f"vsim -view {test_name}.wlf -do {test_name}.do;"
        try:
            subprocess.run(
                sim_command,
                shell=True,
                stdout=transcript,
                stderr=subprocess.PIPE,
                check=True
            )
        except subprocess.CalledProcessError as e:
            # Print error details and exit if the command fails.
            if args.all:
                print(f"{test_name}: Viewing waveforms failed with error {e.returncode}. {e.stderr.decode('utf-8')}")
            else:
                # Print log file contents in case of an error when running a single test.
                with open(f"{test_name}_transcript", 'r') as transcript:
                    print(f"\n===== Viewing waveforms for {test_name} failed with the following errors =====\n")
                    print(transcript.read())
            sys.exit(1)


def find_testbench(find_all=False):
    """
    Search for testbench files in the specified directory.

    This function scans the testbench directory for `.(s)v` files with the `_tb.(s)v` suffix.
    - If no testbench files are found, it raises an error.
    - If `find_all` is True, returns all testbench files (excluding the `.(s)v` extension).
    - If only one testbench file is found, returns its name (excluding the `.(s)v` extension).
    - If multiple testbench files are found, and `find_all` is False, prompts the user to choose one.

    Args:
        find_all (bool): If True, return all testbenches.

    Returns:
        list: A list of testbench names (excluding the `.sv` or `.v` extension).

    Raises:
        FileNotFoundError: If no testbench files matching the criteria are found.
    """
   # Collect all testbench _tb.sv or _tb.v files in the specified directory.
    testbench_names = [
        filename for filename in os.listdir(TESTS_DIR) if filename.endswith(("_tb.sv", "_tb.v"))
    ]

    # If no testbench files are found, raise an error.
    if not testbench_names:
        raise FileNotFoundError("No testbench files ending with '_tb.(s)v' found.")

    # If `find_all` is True, return all testbench names without `.sv` or `.v` extension.
    if find_all:
        return [tb.rsplit('.', 1)[0] for tb in testbench_names]  # Remove the extension

    # If only one testbench file is found, return its name without the extension.
    if len(testbench_names) == 1:
        return [testbench_names[0].rsplit('.', 1)[0]]  # Return as a list for consistency.

    # If multiple testbenches are found, prompt the user to choose one.
    print("Multiple testbench files found. Please choose one:")
    for i, tb_name in enumerate(testbench_names, start=1):
        print(f"  {i}. {tb_name}")

    # Loop to handle user input for selecting a testbench.
    while True:
        try:
            # Ask the user to input their choice.
            choice = int(input("Enter the number corresponding to your choice: "))
            if 1 <= choice <= len(testbench_names):
                # Return the chosen testbench without the extension.
                return [testbench_names[choice - 1].rsplit('.', 1)[0]]
            else:
                # Handle out-of-range inputs.
                print(f"Invalid choice. Please select a number between 1 and {len(testbench_names)}.")
        except ValueError:
            # Handle non-integer inputs.
            print("Invalid input. Please enter a number.")


def execute_test(test_name, args):
    """
    Executes a single test by first ensuring that all dependencies are compiled and then running the test.

    Args:
        test_name (str): The name of the testbench to execute (without the .v extension).
        args (argparse.Namespace): The parsed command-line arguments containing execution details.
        
    The function performs the following steps:
    1. Resolves the full file path for the testbench file.
    2. Finds all the dependencies required for compiling the testbench.
    3. Compiles the required files if necessary.
    4. Executes the testbench with the provided arguments.
    """
    # First, try to find the file with the .sv extension.
    test_file_sv = os.path.join(TESTS_DIR, f"{test_name}.sv")
    
    # If the .sv file exists, use it. Otherwise, try the .v extension.
    if os.path.exists(test_file_sv):
        test_file = test_file_sv
    else:
        # Fallback to .v if .sv doesn't exist.
        test_file = os.path.join(TESTS_DIR, f"{test_name}.v")

    # Find all dependencies for the testbench.
    all_dependencies = find_dependencies(test_file)
    
    # Compile the necessary files (if needed) for the testbench.
    compile_files(test_name, all_dependencies, args)

    # Run the actual test using the provided arguments.
    run_test(test_name, args)


def execute_tests(test_names, args):
    """
    Runs the testbenches in parallel using a ThreadPoolExecutor.
    
    Args:
        test_names (list): A list of testbench names to be executed.
        args (argparse.Namespace): The parsed command-line arguments containing execution details.
        
    This function uses a ThreadPoolExecutor to execute testbenches in parallel. It submits
    each test to the executor and waits for all the tests to complete.
    """
    with concurrent.futures.ThreadPoolExecutor() as executor:
        futures = []
        for test_name in test_names:
            # The job to be submitted to the executor.
            job = None

            # Check the mode and submit the appropriate job.
            if args.mode == 3:
                # Submit task for viewing waveforms.
                job = executor.submit(view_waveforms, test_name, args)
            else:
                # Submit task for executing the test.
                job = executor.submit(execute_test, test_name, args)

            # Submit each job (either execute or view waveforms).
            futures.append(job)

        # Wait for all tests to complete and handle exceptions.
        for future in concurrent.futures.as_completed(futures):
            try:
                result = future.result()  # Get the result (if any)
            except Exception as e:
                # Handle errors during test execution
                print(f"Error during test execution: {e}")
                sys.exit(1)


def print_mode_message(args):
    """
    Prints an appropriate message based on the mode.

    Ensures messages are printed only once, especially when the `-a` (all tests) flag is used
    and tests are run in parallel.

    Args:
        args (argparse.Namespace): Parsed command-line arguments.

    Returns:
        None
    """
    try:
        mode_labels = ["command-line", "saving", "GUI"]

        # Handle messages for all tests (-a flag).
        if args.all:
            if args.mode != 3:
                print(f"Running all tests in {mode_labels[args.mode]} mode...")
            else:
                print("Viewing waveforms for all tests...")
    except Exception as e:
        print(f"Printing message failed with error: {e}")
        sys.exit(1)


def main():
    """
    Main function to parse arguments, set up the environment, and execute tests.
    
    This function serves as the entry point for the test execution process. It handles the
    argument parsing, sets up directories, checks if logs need to be displayed, retrieves
    the testbenches, and runs tests in parallel. If a FileNotFoundError occurs, the process 
    will exit gracefully.
    """
    args = parse_arguments()
    
    try:
        setup_directories(choose_directory(args))
        
        # Handle log file display and exit, otherwise check design files, or run tests / view waves.
        if args.logs:
            display_log(args.logs)
        elif args.check:
            check_design_files()
        else:
            # Assemble the selected input file if not all tests running in parallel.
            if args.asm and not args.all:
                assemble()

            # Retrieve testbenches to be run
            test_names = find_testbench(args.all)

            # Display the appropriate message based on mode.
            print_mode_message(args)

            # Run the tests in parallel.
            execute_tests(test_names, args)
    except FileNotFoundError as e:
        # Handle missing file errors
        print(e)
        sys.exit(1)

if __name__ == "__main__":
    main()