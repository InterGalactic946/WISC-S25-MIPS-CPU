import re
from collections import defaultdict

# Define the log file
log_file = "./Phase-2/tests/output/logs/transcript/cpu_tb_transcript.log"
output_file = "formatted_log_output.txt"

# Regular expressions for different stages
instruction_pattern = re.compile(r"ID: (\d+)\. (.*?) @ Cycle: (\d+)")
fetch_pattern = re.compile(r"ID: (\d+). \|(\[FETCH\].*?)@ Cycle: (\d+)")
decode_pattern = re.compile(r"ID: (\d+). \|(\[DECODE\].*?)@ Cycle: (\d+)")
execute_pattern = re.compile(r"ID: (\d+). \|(\[EXECUTE\].*?)@ Cycle: (\d+)")
memory_pattern = re.compile(r"ID: (\d+). \|(\[MEMORY\].*?)@ Cycle: (\d+)")
writeback_pattern = re.compile(r"ID: (\d+). \|(\[WRITE-BACK\].*?)@ Cycle: (\d+)")

# Dictionary to store grouped log messages for each instruction ID
instruction_logs = defaultdict(lambda: {
    "instruction": None,
    "fetch": None,
    "decode": None,
    "execute": None,
    "memory": None,
    "writeback": None,
    "wb_cycle": None
})

# Read and process the log file
with open(log_file, 'r') as file:
    for line in file:
        # Capture instruction lines
        instruction_match = instruction_pattern.search(line)
        if instruction_match:
            instr_id, instruction, _ = instruction_match.groups()
            instr_id = int(instr_id)
            instruction_logs[instr_id]["instruction"] = instruction

        # Capture fetch stage
        fetch_match = fetch_pattern.search(line)
        if fetch_match:
            instr_id, msg, cycle = fetch_match.groups()
            instr_id, cycle = int(instr_id), int(cycle)
            instruction_logs[instr_id]["fetch"] = f"|{msg} @ Cycle: {cycle} |"

        # Capture decode stage
        decode_match = decode_pattern.search(line)
        if decode_match:
            instr_id, msg, cycle = decode_match.groups()
            instr_id, cycle = int(instr_id), int(cycle)
            instruction_logs[instr_id]["decode"] = f"|{msg} @ Cycle: {cycle} |"

        # Capture execute stage
        execute_match = execute_pattern.search(line)
        if execute_match:
            instr_id, msg, cycle = execute_match.groups()
            instr_id, cycle = int(instr_id), int(cycle)
            instruction_logs[instr_id]["execute"] = f"|{msg} @ Cycle: {cycle} |"

        # Capture memory stage
        memory_match = memory_pattern.search(line)
        if memory_match:
            instr_id, msg, cycle = memory_match.groups()
            instr_id, cycle = int(instr_id), int(cycle)
            instruction_logs[instr_id]["memory"] = f"|{msg} @ Cycle: {cycle} |"

        # Capture write-back stage and store the final cycle number
        writeback_match = writeback_pattern.search(line)
        if writeback_match:
            instr_id, msg, cycle = writeback_match.groups()
            instr_id, cycle = int(instr_id), int(cycle)
            instruction_logs[instr_id]["writeback"] = f"|{msg} @ Cycle: {cycle} |"
            instruction_logs[instr_id]["wb_cycle"] = cycle  # Store completion cycle

# Format and write output
with open(output_file, 'w') as out_file:
    for instr_id in sorted(instruction_logs.keys()):
        entry = instruction_logs[instr_id]
        instruction = entry["instruction"]
        wb_cycle = entry["wb_cycle"] if entry["wb_cycle"] is not None else "N/A"

        # Print instruction header with the correct cycle from the write-back stage
        out_file.write("========================================================\n")
        out_file.write(f"| Instruction: {instruction} | Completed At Cycle: {wb_cycle} |\n")
        out_file.write("========================================================\n")

        # Print each stage if it exists
        for stage in ["fetch", "decode", "execute", "memory", "writeback"]:
            if entry[stage]:
                out_file.write(entry[stage] + "\n")

print("Processing complete. Output written to 'formatted_log_output.txt'.")
