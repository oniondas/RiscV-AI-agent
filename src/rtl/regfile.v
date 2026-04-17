module regfile (
    input wire clk,
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [4:0] rd,
    input wire [31:0] wdata,
    input wire we,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2,
    output wire [31:0] x3_gp
);
    reg [31:0] regs [0:31];
    
    integer i;
    initial begin
        for (i=0; i<32; i=i+1) regs[i] = 0;
    end

    assign rdata1 = (rs1 == 0) ? 32'b0 : regs[rs1];
    assign rdata2 = (rs2 == 0) ? 32'b0 : regs[rs2];
    assign x3_gp = regs[3];

    always @(posedge clk) begin
        if (we && rd != 0) begin
            regs[rd] <= wdata;
        end
    end
endmodule
