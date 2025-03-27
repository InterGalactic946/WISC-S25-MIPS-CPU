import re
from collections import defaultdict

# Read the log file
log_file = "../Phase-2/output/logs/transcript/cpu_tb_transcript.log"
stages = ['FETCH', 'DECODE', 'EXECUTE', 'MEMORY', 'WRITE-BACK']
instructions = defaultdict(list)

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
        instructions[instr_id].append({'stage': stage, 'msg': msg, 'cycle': cycle})

# Helper function to extract the instruction and cycle for general lines
def process_instruction_line(line):
    match = instruction_pattern.search(line)
    if match:
        instr_id, instruction, cycle = match.groups()
        instr_id = int(instr_id)
        cycle = int(cycle)
        instructions[instr_id].append({'stage': 'INSTRUCTION', 'msg': instruction, 'cycle': cycle})

# Process the log file
with open(log_file, 'r') as file:
    for line in file:
        # Check for instructions with specific stages
        process_log_line(line, fetch_pattern, 'FETCH')
        process_log_line(line, decode_pattern, 'DECODE')
        process_log_line(line, execute_pattern, 'EXECUTE')
        process_log_line(line, memory_pattern, 'MEMORY')
        process_log_line(line, writeback_pattern, 'WRITE-BACK')
        
        # Check for general instruction lines and extract the instruction name
        process_instruction_line(line)

# Sort instructions by cycle within each instruction ID
output = []

for instr_id, stages_list in instructions.items():
    # Sort by cycle
    stages_list.sort(key=lambda x: x['cycle'])

    # Extract the instruction message
    instruction = next((stage['msg'] for stage in stages_list if stage['stage'] == 'INSTRUCTION'), "Unknown Instruction")
    
    # Get the cycle when the instruction is completed
    last_cycle = stages_list[-1]['cycle']

    # Format the instruction output
    output.append(f"========================================================")
    output.append(f"| Instruction: {instruction} | Completed At Cycle: {last_cycle} |")
    output.append(f"========================================================")
    
    for stage in stages_list:
        output.append(f"|[{stage['stage']}] {stage['msg']} @ Cycle: {stage['cycle']} |")
    output.append(f"========================================================\n")

# Write to output file
with open("formatted_log_output.txt", 'w') as output_file:
    output_file.write("\n".join(output))

print("Processing complete. Output written to 'formatted_log_output.txt'.")
