#include "Vrv32i_core.h"
#include "verilated.h"
#include <iostream>
#include <fstream>
#include <stdint.h>
#include <stdlib.h>

#define MEM_SIZE 8*1024*1024 // 32 MB
uint32_t memory[MEM_SIZE]; 

uint32_t get_mem_word(uint32_t addr) {
    uint32_t offset = addr & ((MEM_SIZE * 4) - 1);
    if ((addr >= 0x80000000 && addr < 0x80000000 + MEM_SIZE * 4) || (addr < MEM_SIZE * 4)) {
        return memory[offset >> 2];
    }
    return 0;
}

void write_mem_word(uint32_t addr, uint32_t wdata, uint8_t we) {
    uint32_t offset = addr & ((MEM_SIZE * 4) - 1);
    if ((addr >= 0x80000000 && addr < 0x80000000 + MEM_SIZE * 4) || (addr < MEM_SIZE * 4)) {
        uint32_t idx = offset >> 2;
        uint32_t old = memory[idx];
        if (we & 1) old = (old & 0xffffff00) | (wdata & 0x000000ff);
        if (we & 2) old = (old & 0xffff00ff) | (wdata & 0x0000ff00);
        if (we & 4) old = (old & 0xff00ffff) | (wdata & 0x00ff0000);
        if (we & 8) old = (old & 0x00ffffff) | (wdata & 0xff000000);
        memory[idx] = old;
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vrv32i_core* top = new Vrv32i_core;
    
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <firmware.bin>\n";
        return 1;
    }
    
    FILE *f = fopen(argv[1], "rb");
    if (!f) {
        std::cerr << "Cannot open " << argv[1] << "\n";
        return 1;
    }
    fread(memory, 1, MEM_SIZE * 4, f);
    fclose(f);
    
    top->clk = 0;
    top->rst_n = 0;
    
    long ticks = 0;
    uint32_t x3_pass_val = 0;
    
    // Reset sequence
    for(int i=0; i<4; i++) {
        top->clk = !top->clk;
        top->eval();
    }
    top->rst_n = 1;
    
    // PC starts at 0 initially, wait, riscv-tests are compiled to base 0x80000000.
    // Our core resets PC to 0x0. Let's assume we map 0x0 to 0x80000000 or change reset vector.
    // We didn't add a reset vector injection, so our PC resets to 0. Let's just treat physical addr 0 as memory index 0.
    
    uint32_t prev_pc = 0;
    while (!Verilated::gotFinish() && ticks < 100000) {
        // Evaluate imem logically
        top->imem_rdata = get_mem_word(top->imem_addr);
        top->eval(); // Propagate imem_rdata all the way to dmem_addr

        // Evaluate dmem using the now stable dmem_addr
        top->dmem_rdata = get_mem_word(top->dmem_addr);
        top->eval(); // Settles all combinatorial signals for the current instruction
        
        // Posedge clock triggers register updates
        top->clk = 1;
        top->eval();
        
        // Memory writes usually commit exactly after clock edge
        if (top->dmem_we) {
            write_mem_word(top->dmem_addr, top->dmem_wdata, top->dmem_we);
        }
        
        // Return to low and settle
        top->clk = 0;
        top->eval();
        
        if (ticks > 10 && top->imem_addr == prev_pc) {
            // Infinite loop detected (usually RVTEST_FAIL ends with `1: j 1b`)
            if (top->x3_gp != 1) {
                std::cout << "TEST FAILED. gp=" << top->x3_gp << "\n";
                std::cout << "Failing test number: " << top->x3_gp << "\n";
                break;
            }
        }
        prev_pc = top->imem_addr;
        
        ticks++;
        
        // Check for pass in gp (x3)
        // riscv-tests writes 1 to gp for pass.
        if (top->x3_gp == 1) {
            std::cout << "TEST PASSED!\n";
            break;
        }
    }
    
    if (top->x3_gp == 0) {
        std::cout << "TEST TIMEOUT or no status written.\n";
    }
    
    delete top;
    return 0;
}
