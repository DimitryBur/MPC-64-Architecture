#include <stdint.h>
#include <stdio.h>

// Определение команд ISA MPC-64
#define V_NOP        0x00
#define V_LD_WIDE    0x01 // Загрузка 1024-бит из L1 в регистр
#define V_TMAC_4X4   0x02 // Тензорное умножение-сложение (4 такта)
#define V_LOGIC_AND  0x03 // Побитовое И
#define V_ST_WIDE    0x04 // Сохранение результата в L1/Выход
#define V_DONE_SIG   0x0F // Сигнал завершения для планировщика

// Структура инструкции (64 бита)
typedef struct {
    uint8_t  opcode;    // Код операции
    uint8_t  reg_dest;  // Регистр назначения
    uint8_t  reg_src1;  // Источник 1
    uint8_t  reg_src2;  // Источник 2
    uint32_t immediate; // Адрес в L1 или константа
} mpc64_inst_t;

// Функция генерации бинарного блока для ядра
void generate_core_firmware() {
    mpc64_inst_t program[6] = {
        {V_LD_WIDE,   1, 0, 0, 0x0000}, // Load Activations to V1
        {V_LD_WIDE,   2, 0, 0, 0x0040}, // Load Weights to V2 (offset 64 bytes)
        {V_TMAC_4X4,  3, 1, 2, 0x0000}, // V3 = V1 * V2 + V_ACC
        {V_LOGIC_AND, 3, 3, 0, 0x00FF}, // Masking result
        {V_ST_WIDE,   0, 3, 0, 0x0080}, // Store result to L1 output zone
        {V_DONE_SIG,  0, 0, 0, 0x0000}  // Signal: "I'm free"
    };

    printf("--- MPC-64 CORE FIRMWARE DUMP ---\n");
    for(int i=0; i<6; i++) {
        printf("Addr %02d: OP:%02X DST:%d SRC1:%d SRC2:%d IMM:%08X\n", 
                i, program[i].opcode, program[i].reg_dest, 
                program[i].reg_src1, program[i].reg_src2, program[i].immediate);
    end
}

int main() {
    generate_core_firmware();
    return 0;
}
