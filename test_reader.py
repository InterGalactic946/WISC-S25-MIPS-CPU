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
        return f"|[{stage}] {msg} @ Cycle: {cycle} |"

# Helper function to extract the instruction and cycle for general lines
def process_instruction_line(line):
    match = instruction_pattern.search(line)
    if match:
        instr_id, instruction, cycle = match.groups()
        instr_id = int(instr_id)
        cycle = int(cycle)
        return f"========================================================\n| Instruction: {instruction} @ Cycle: {cycle} |"

# Process the log file
with open(log_file, 'r') as file:
    output = []
    for line in file:
        # Check for instruction lines
        instruction_line = process_instruction_line(line)
        if instruction_line:
            output.append(instruction_line)

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

        writeback_line = process_log_line(line, writeback_pattern, 'WRITE-BACK')
        if writeback_line:
            output.append(writeback_line)

# Write to output file
with open(output_file, 'w') as out_file:
    out_file.write("\n".join(output))

print("Processing complete. Output written to 'formatted_log_output.txt'.")
