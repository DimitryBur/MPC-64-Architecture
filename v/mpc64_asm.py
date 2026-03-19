import sys

class MPC64Assembler:
    def __init__(self):
        # Opcodes from our ISA.md
        self.opcodes = {
            "VADD":  "0001",
            "VSUB":  "0010",
            "VMUL":  "0011",
            "VRELU": "1000",
            "VMAC":  "1001",
            "VRED":  "1010",
            "HALT":  "1111",
            "NOP":   "0000"
        }

    def assemble_line(self, line):
        line = line.split("//")[0].strip() # Remove comments
        if not line: return None
        
        parts = line.replace(',', ' ').split()
        mnemonic = parts[0].upper()
        
        if mnemonic not in self.opcodes:
            return f"// Error: Unknown instruction {mnemonic}"

        opcode = self.opcodes[mnemonic]
        
        # Default values for registers and mask
        dst = src1 = src2 = "0000"
        mask = "1111111111111111" # 16-bit mask (all ones)
        imm = "0" * 32

        # Simple parser for registers (V0-V15)
        def reg_to_bin(r):
            return format(int(r.replace('V', '')), '04b')

        try:
            if mnemonic != "HALT" and mnemonic != "NOP":
                dst = reg_to_bin(parts[1])
                src1 = reg_to_bin(parts[2])
                if len(parts) > 3 and parts[3].startswith('V'):
                    src2 = reg_to_bin(parts[3])
        except: pass

        # Construct 64-bit word: Op(4) + Dst(4) + Src1(4) + Src2(4) + Mask(16) + Imm(32)
        binary_instruction = f"{opcode}{dst}{src1}{src2}{mask}{imm}"
        return binary_instruction

    def process_file(self, input_file, output_file):
        with open(input_file, 'r') as f:
            lines = f.readlines()

        with open(output_file, 'w') as f:
            f.write("// MPC-64 Binary Firmware\n")
            for line in lines:
                binary = self.assemble_line(line)
                if binary:
                    f.write(f"{binary}\n")

# Usage: python mpc64_asm.py kernel.asm firmware.mem
if __name__ == "__main__":
    asm = MPC64Assembler()
    # Simple test run
    test_code = [
        "VMUL V3, V1, V2",
        "VRED V3, V3",
        "VRELU V3, V3",
        "HALT"
    ]
    print("// Assembling test kernel...")
    for l in test_code:
        print(asm.assemble_line(l))
