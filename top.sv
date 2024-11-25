module TOP(
    input   clk,
    input   rst_n,
    output  [31:0] pc,
    output  [31:0] inst
);

// Internal wires for IDU outputs
wire [4:0]  idu_rd;
wire [4:0]  idu_rs1;
wire [4:0]  idu_rs2;
wire [31:0] idu_imm;
wire        idu_alu_src;
wire        idu_mem_read;
wire        idu_mem_write;
wire        idu_reg_write;
wire [3:0]  idu_alu_op;
wire [1:0]  idu_mem_size;
wire        idu_valid;

IFU IFU(
    .clk(clk),
    .rst_n(rst_n),
    .pc(pc),
    .inst(inst)
);

IDU IDU(
    .clk(clk),
    .rst_n(rst_n),
    .inst_i(inst),      // Connect to instruction from IFU
    .valid_i(1'b1),     // Assuming instruction is always valid for now
    
    // Decoded instruction fields
    .rd_o(idu_rd),
    .rs1_o(idu_rs1),
    .rs2_o(idu_rs2),
    .imm_o(idu_imm),
    
    // Control signals
    .alu_src_o(idu_alu_src),
    .mem_read_o(idu_mem_read),
    .mem_write_o(idu_mem_write),
    .reg_write_o(idu_reg_write),
    .alu_op_o(idu_alu_op),
    .mem_size_o(idu_mem_size),
    .valid_o(idu_valid)
);

endmodule