module ISQ(
    input wire clk,
    input wire rst_n,
    
    // From RNU
    input wire [5:0] rn2iq_rs1_p,    // Physical register number for rs1
    input wire [5:0] rn2iq_rs2_p,    // Physical register number for rs2
    input wire [5:0] rn2iq_rd_p,     // Physical register number for rd

    
    // Control signals form IDU
    input wire [6:0] id2iq_opcode,
    input wire id2iq_alu_src,        // 0: wire, 1: imm
    input wire id2iq_mem_read,       // Memory read enable
    input wire id2iq_mem_write,      // Memory write enable
    input wire id2iq_wire_write,      // wireister write enable
    input wire [3:0] id2iq_alu_op,   // ALU operation
    input wire [1:0] id2iq_mem_size, // 00: byte, 10: word
    input wire id2iq_valid           // Decoded instruction valid
    input wire [31:0] id2iq_imm,     // Immediate value

    // Verify the scr1 and scr2 ready status from ROB
    input wire rob2iq_scr1ready,
    input wire rob2iq_scr2ready,
    input wire rob2iq_current_num, // Current ROB number

    // Function Unit ready status
    input wire alu2iq_ready1,
    input wire alu2iq_ready2,
    input wire mem2iq_ready,
    
    // Send the scr1 scr2 to ROB to check if ready
    output wire iq2rob_scr1,
    output wire iq2rob_scr2

    //Send the instruction to FU
    // output reg iq2alu1_rs1,
    // output reg iq2alu1_rs2,
    // output reg iq2alu1_rd,
    // output reg iq2alu1_imm,

    // output reg iq2alu2_rs1,
    // output reg iq2alu2_rs2,
    // output reg iq2alu2_rd,
    // output reg iq2alu2_imm,

    // output reg iq2mem_rs1,
    // output reg iq2mem_rs2,
    // output reg iq2mem_rd,
    // output reg iq2mem_imm

);

// Issue Queue
reg [0:50] issue_queue[63:0];

//Find first free column
reg [6:0]   next_free_column;
reg         next_column_flag;       

integer i;
always @ (*) begin
    for (i = 0; i < IQ_SIZE; i = i + 1) begin
        if ((issue_queue[i][0] == 0) && next_column_flag) begin
            next_free_column = i[6:0];
            next_column_flag = 1'b1;
        end
    end
end

// Direct the scr1 and scr2 to ROB and get ready status
assign iq2rob_scr1 = rn2iq_rs1_p;
assign iq2rob_scr2 = rn2iq_rs2_p;


wire scr1_ready;
wire scr2_ready;

assign scr1_ready = rob2iq_scr1ready;
assign scr2_ready = rob2iq_scr2ready;

// Check it should go to alu or mem
assign to_alu = (id2iq_opcode == R_TYPE) || (id2iq_opcode == I_TYPE) || (id2iq_opcode == LUI);
assign to_mem = (id2iq_opcode == LOAD) || (id2iq_opcode == STORE);


always @ (posedge clk or negedge rst_n) begin
    if (!rst_n)
        alu_assign <= 1'b0;
    else if () // RR for ALU for R-type and I-type and LUI
        alu_assign <= ~alu_assign;
end

// Store the values in the issue queue column
integer k;
always @(posedge clk or negedge rst_n) begin
    for (k = 0; k < IQ_SIZE; i = i + 1) begin
        if (!rst_n)
            issue_queue[k] <= 50'b0;
        else (rn2iq_valid & id2iq_valid && to_alu)
            issue_queue[k] <= {rob2iq_current_num, rn2iq_rd_p, rn2iq_rs1_p, scr1_ready, rn2iq_rs2_p, scr2_ready, id2iq_rs2, id2iq_imm, 1'b0, alu_assign, id2iq_opcode, id2iq_alu_src, id2iq_mem_read, id2iq_mem_write, id2iq_wire_write, id2iq_alu_op, id2iq_mem_size, 1'b1};
        else (rn2iq_valid & id2iq_valid && to_mem)
            issue_queue[k] <= {rob2iq_current_num, rn2iq_rd_p, rn2iq_rs1_p, scr1_ready, rn2iq_rs2_p, scr2_ready, id2iq_rs2, id2iq_imm, 2'b10, id2iq_opcode, id2iq_alu_src, id2iq_mem_read, id2iq_mem_write, id2iq_wire_write, id2iq_alu_op, id2iq_mem_size, 1'b1};
    end 
end

// --------------------------------------------------------------------------------
// Issue Out
// --------------------------------------------------------------------------------
// Check if the column is used and scr1 and scr2 are ready
// If FU is ready, send the instruction to FU and remove from IQ



