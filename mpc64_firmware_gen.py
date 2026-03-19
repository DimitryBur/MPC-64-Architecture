import binascii

class MPC64_Assembler:
    def __init__(self):
        # Коды операций (согласно ALU.v в проекте)
        self.ops = {
            'NOP':  '0000',
            'ADD':  '0001',
            'SUB':  '0010',
            'MUL':  '0011',
            'SHL':  '0100',
            'SHR':  '0101',
            'AND':  '0110',
            'OR':   '0111',
            'RELU': '1000', # Предлагаемая доработка для ИИ
            'MAC':  '1001'  # Multiply-Accumulate
        }

    def create_instruction(self, op, reg_dest, reg_src1, reg_src2):
        """Формирует 64-битную команду для планировщика"""
        opcode = self.ops.get(op, '0000')
        # В 64-битном слове упаковываем: Opcode (4 бита), Адреса регистров и доп. флаги
        instr = f"{opcode}{reg_dest:04b}{reg_src1:04b}{reg_src2:04b}"
        return instr.ljust(64, '0')

    def generate_task_add_vectors(self):
        """Прошивка: Сложить два 1024-битных вектора"""
        return [
            self.create_instruction('ADD', 1, 1, 2), # R1 = R1 + R2 (все 1024 бита)
            self.create_instruction('NOP', 0, 0, 0)
        ]

    def generate_task_ai_block(self):
        """Прошивка для ИИ: Умножение с накоплением и активация ReLU"""
        return [
            self.create_instruction('MAC', 3, 1, 2),  # R3 = (R1 * R2) + R3
            self.create_instruction('RELU', 3, 3, 0), # Обнулить отрицательные значения в 1024-битном векторе
            self.create_instruction('NOP', 0, 0, 0)
        ]

# Пример использования:
asm = MPC64_Assembler()
firmware = asm.generate_task_ai_block()

print("// MPC-64 SRAM Image for Scheduler")
for i, instr in enumerate(firmware):
    print(f"ADDR_{i:03d}: {instr}")
