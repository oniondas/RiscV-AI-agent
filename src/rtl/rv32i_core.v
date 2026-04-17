/* verilator lint_off DECLFILENAME */

module rv32i_core (
    input wire clk,
    input wire rst_n,
    
    // Instruction Memory Interface
    output wire [31:0] imem_addr,
    input wire [31:0] imem_rdata,

    // Data Memory Interface
    output wire [31:0] dmem_addr,
    output wire [3:0] dmem_we,
    output wire [31:0] dmem_wdata,
    input wire [31:0] dmem_rdata,

    // Testing Interface
    output wire [31:0] x3_gp
);

    reg [31:0] pc;
    wire [31:0] instr = imem_rdata;
    
    assign imem_addr = pc;

    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];
    wire [4:0] rs1 = instr[19:15];
    wire [4:0] rs2 = instr[24:20];
    wire [4:0] rd = instr[11:7];

    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};
    wire [31:0] imm_j = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};

    wire is_lui    = (opcode == 7'b0110111);
    wire is_auipc  = (opcode == 7'b0010111);
    wire is_jal    = (opcode == 7'b1101111);
    wire is_jalr   = (opcode == 7'b1100111);
    wire is_branch = (opcode == 7'b1100011);
    wire is_load   = (opcode == 7'b0000011);
    wire is_store  = (opcode == 7'b0100011);
    wire is_alu_i  = (opcode == 7'b0010011);
    wire is_alu_r  = (opcode == 7'b0110011);

    wire [31:0] rdata1;
    wire [31:0] rdata2;
    reg [31:0] wdata;
    wire reg_write = (is_lui | is_auipc | is_jal | is_jalr | is_load | is_alu_i | is_alu_r);

    regfile rf (
        .clk(clk),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .wdata(wdata),
        .we(reg_write),
        .rdata1(rdata1),
        .rdata2(rdata2),
        .x3_gp(x3_gp)
    );

    wire [31:0] alu_in1 = (is_auipc | is_jal) ? pc : rdata1;
    
    reg [31:0] alu_in2;
    always @(*) begin
        if (is_alu_r | is_branch) alu_in2 = rdata2;
        else if (is_alu_i | is_load | is_jalr) alu_in2 = imm_i;
        else if (is_store) alu_in2 = imm_s;
        else if (is_auipc) alu_in2 = imm_u;
        else if (is_jal) alu_in2 = imm_j;
        else alu_in2 = 32'b0;
    end

    reg [3:0] alu_ctrl;
    always @(*) begin
        if (is_alu_r || is_alu_i) begin
            case (funct3)
                3'b000: alu_ctrl = (is_alu_r && funct7[5]) ? 4'b1000 : 4'b0000; // ADD/SUB
                3'b001: alu_ctrl = 4'b0001; // SLL
                3'b010: alu_ctrl = 4'b0010; // SLT
                3'b011: alu_ctrl = 4'b0011; // SLTU
                3'b100: alu_ctrl = 4'b0100; // XOR
                3'b101: alu_ctrl = (funct7[5]) ? 4'b1101 : 4'b0101; // SRL/SRA
                3'b110: alu_ctrl = 4'b0110; // OR
                3'b111: alu_ctrl = 4'b0111; // AND
            endcase
        end else if (is_branch) begin
            case (funct3)
                3'b000, 3'b001: alu_ctrl = 4'b1000; // SUB for BEQ, BNE
                3'b100, 3'b101: alu_ctrl = 4'b0010; // SLT for BLT, BGE
                3'b110, 3'b111: alu_ctrl = 4'b0011; // SLTU for BLTU, BGEU
                default: alu_ctrl = 4'b0000;
            endcase
        end else begin
            alu_ctrl = 4'b0000; // ADD for load, store, auipc, jal, jalr
        end
    end

    wire [31:0] alu_out;
    wire zero;
    
    alu alu_inst (
        .in1(alu_in1),
        .in2(alu_in2),
        .ctrl(alu_ctrl),
        .out(alu_out),
        .zero(zero)
    );

    assign dmem_addr = alu_out;
    assign dmem_wdata = (is_store && funct3 == 3'b000) ? {4{rdata2[7:0]}} : 
                        (is_store && funct3 == 3'b001) ? {2{rdata2[15:0]}} : rdata2;
    
    // Store masking based on funct3
    reg [3:0] we;
    always @(*) begin
        if (is_store) begin
            case (funct3)
                3'b000: we = 4'b0001 << (alu_out[1:0]); // SB
                3'b001: we = 4'b0011 << (alu_out[1:0]); // SH
                3'b010: we = 4'b1111; // SW
                default: we = 4'b0000;
            endcase
        end else begin
            we = 4'b0000;
        end
    end
    assign dmem_we = we;

    // Load formatting based on funct3
    wire [31:0] raw_rdata = dmem_rdata >> {alu_out[1:0], 3'b000};
    reg [31:0] load_data;
    always @(*) begin
        case (funct3)
            3'b000: load_data = {{24{raw_rdata[7]}}, raw_rdata[7:0]}; // LB
            3'b001: load_data = {{16{raw_rdata[15]}}, raw_rdata[15:0]}; // LH
            3'b010: load_data = dmem_rdata; // LW (always aligned)
            3'b100: load_data = {24'b0, raw_rdata[7:0]}; // LBU
            3'b101: load_data = {16'b0, raw_rdata[15:0]}; // LHU
            default: load_data = dmem_rdata;
        endcase
    end

    always @(*) begin
        if (is_lui) wdata = imm_u;
        else if (is_jal | is_jalr) wdata = pc + 4;
        else if (is_load) wdata = load_data; // use formatted load
        else wdata = alu_out;
    end

    wire take_branch = is_branch && (
        (funct3 == 3'b000 && zero) || // BEQ
        (funct3 == 3'b001 && !zero) || // BNE
        (funct3 == 3'b100 && alu_out[0]) || // BLT
        (funct3 == 3'b101 && !alu_out[0]) || // BGE
        (funct3 == 3'b110 && alu_out[0]) || // BLTU
        (funct3 == 3'b111 && !alu_out[0]) // BGEU
    );

    wire [31:0] next_pc = (take_branch || is_jal) ? (pc + ((is_jal) ? imm_j : imm_b)) :
                          (is_jalr) ? ((rdata1 + imm_i) & ~32'b1) : (pc + 4);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc <= 32'h8000_0000;
        else pc <= next_pc;
    end

endmodule

/* verilator lint_on DECLFILENAME */
