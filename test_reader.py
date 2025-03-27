import re

# Define the log file
log_file = "./Phase-2/tests/output/logs/transcript/cpu_tb_transcript.log"
output_file = "formatted_log_output.txt"

# Regular expressions for parsing different stages
fetch_pattern = re.compile(r"ID: (\d+). \|(\[FETCH\].*?)@ Cycle: (\d+)")
decode_pattern = re.compile(r"ID: (\d+). \|(\[DECODE\].*?)@ Cycle: (\d+)")
execute_pattern = re.compile(r"ID: (\d+). \|(\[EXECUTE\].*?)@ Cycle: (\d+)")
memory_pattern = re.compile(r"ID: (\d+). \|(\[MEMORY\].*?)@ Cycle: (\d+)")
writeback_pattern = re.compile(r"ID: (\d+). \|(\[WRITE-BACK\].*?)@ Cycle: (\d+)")

# Regular expression for extracting instruction name from a line like `# ID: 0. LLB R1, 0x0002 @ Cycle: 4`
instruction_pattern = re.compile(r"ID: (\d+)\. (.*?) @ Cycle: (\d+)")

# Helper function to parse each log line and group by ID and cycle
def process_log_line(line, pattern, stage):
    match = pattern.search(line)
    if match:
        instr_id, msg, cycle = match.groups()
        instr_id = int(instr_id)
        cycle = int(cycle)
        return msg

# Store instructions and their write-back cycle numbers for later use in formatting the header
instruction_cycles = {}

# Process the log file
with open(log_file, 'r') as file:
    output = []
    for line in file:
        # Check for WRITE-BACK lines to store the cycle number for each instruction
        writeback_line = writeback_pattern.search(line)
        if writeback_line:
            instr_id, msg, cycle = writeback_line.groups()
            instr_id = int(instr_id)
            cycle = int(cycle)
            instruction_cycles[instr_id] = cycle

        # Check for instruction lines and use the cycle from the WRITE-BACK line for the header
        instruction_line = instruction_pattern.search(line)
        if instruction_line:
            instr_id, instruction, _ = instruction_line.groups()
            instr_id = int(instr_id)
            # Retrieve the cycle from the WRITE-BACK line for this instruction
            cycle = instruction_cycles.get(instr_id, "N/A")  # Use "N/A" if cycle is not found
            output.append(f"========================================================\n| Instruction: {instruction} | Completed At Cycle: {cycle} |")

        # Check for stages and process each stage
        fetch_line = process_log_line(line, fetch_pattern, 'FETCH')
        if fetch_line:
            output.append(fetch_line)

        decode_line = process_log_line(line, decode_pattern, 'DECODE')
        if decode_line:
            output.append(decode_line)

        execute_line = process_log_line(line, execute_pattern, 'EXECUTE')
        if execute_line:
            output.append(execute_line)

        memory_line = process_log_line(line, memory_pattern, 'MEMORY')
        if memory_line:
            output.append(memory_line)

# Write to output file
with open(output_file, 'w') as out_file:
    out_file.write("\n".join(output))

print("Processing complete. Output written to 'formatted_log_output.txt'.")
