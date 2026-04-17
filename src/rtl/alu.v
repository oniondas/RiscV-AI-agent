module alu (
    input wire [31:0] in1,
    input wire [31:0] in2,
    input wire [3:0] ctrl,
    output reg [31:0] out,
    output wire zero
);
    assign zero = (out == 0);
    always @(*) begin
        case (ctrl)
            4'b0000: out = in1 + in2; // ADD
            4'b1000: out = in1 - in2; // SUB
            4'b0001: out = in1 << in2[4:0]; // SLL
            4'b0010: out = ($signed(in1) < $signed(in2)) ? 32'b1 : 32'b0; // SLT
            4'b0011: out = (in1 < in2) ? 32'b1 : 32'b0; // SLTU
            4'b0100: out = in1 ^ in2; // XOR
            4'b0101: out = in1 >> in2[4:0]; // SRL
            4'b1101: out = $signed(in1) >>> in2[4:0]; // SRA
            4'b0110: out = in1 | in2; // OR
            4'b0111: out = in1 & in2; // AND
            default: out = 32'b0;
        endcase
    end
endmodule
