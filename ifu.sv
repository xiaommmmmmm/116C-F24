module IFU(
    input clk,
    input rst_n,
    output reg [31:0] if2id_pc,
    output reg [31:0] if2id_inst,
    output reg if2id_valid
);

// if2id_instruction memory
reg [7:0] imem [0:1023]; // Byte-addressable

// Increment the PC
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        if2id_pc <= 32'b0;
    else
        if2id_pc <= if2id_pc + 4;
end

// Read the instruction from memory
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        if2id_inst <= 32'b0;
    else
        if2id_inst <= {imem[if2id_pc], imem[if2id_pc+1], imem[if2id_pc+2], imem[if2id_pc+3]};
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        if2id_valid <= 1'b0;
    else (if2id_inst && if2id_pc)
        if2id_valid <= 1'b1;
end
endmodule
