module RNMU (
    input wire clk,
    input wire rst_n,
    
    // From id get the reg need to rename
    input wire id2rn_valid,              // Instruction is valid
    input wire [4:0] id2rn_rs1,         // Source register 1
    input wire [4:0] id2rn_rs2,         // Source register 2 
    input wire [4:0] id2rn_rd,          // Destination register
    input wire id2rn_rd_write,          // Register write enable (exclude the situation for store)
    input wire [31:0] id2rn_pc,      // Program counter
    
    // output to issue queue
    output wire [5:0] rn2iq_rs1_p,    // Physical register number for rs1
    output wire [5:0] rn2iq_rs2_p,    // Physical register number for rs2
    output wire [5:0] rn2iq_rd_p,     // Physical register number for rd

    // output to ROB about the renaming
    output wire [5:0] rn2rob_rd_p_old, // Original Physical register number for rd
    output wire [5:0] rn2rob_rd_p_new, // Renamed Physical register number for rd

    
    // Free list management
    output wire no_free_reg,  // No free physical registers available

);

// Parameters
parameter NUM_PHYS_REGS = 64;       // Number of physical registers
parameter NUM_ARCH_REGS = 32;       // Number of architectural registers

// Register Alias Table and Free Pool
reg [5:0]  rat[0:31];              // Maps arch regs to physical regs
reg [63:0] free_list;              // 1 = free, 0 = allocated

// Find first free register
reg [5:0] next_free_reg;
reg next_get_flag;
integer i;

always @(*) begin
    next_free_reg = 6'd0;
    for (i = 0; i < NUM_PHYS_REGS; i = i + 1) begin
        if (free_list[i] && (!next_get_flag)) begin
            next_free_reg = i[5:0];
            next_get_flag = 1'b1;
        end
    end
end

// Rename table management
integer k;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Initialize RAT - each arch reg points to itself
        for (k = 0; k < NUM_ARCH_REGS; k = k + 1) begin
            rat[k] <= k[5:0];
        end
        free_list <= {32'hFFFFFFFF, 32'h00000000};
    end
    else
else if (id2rn_valid && id2rn_rd_write) begin
        if (id2rn_rd != 5'b0) begin  // Don't rename r0
            rat[id2rn_rd] <= next_free_reg;
            free_list[next_free_reg] <= 1'b0;  // Mark as allocated
        end
    end
end

// Output renamed registers
assign rn2iq_rs1_p = (id2rn_rs1 == 5'b0) ? 6'b0 : rat[id2rn_rs1];
assign rn2iq_rs2_p = (id2rn_rs2 == 5'b0) ? 6'b0 : rat[id2rn_rs2];
assign rn2iq_rd_p = (id2rn_rd == 5'b0) ? 6'b0 : next_free_reg;

// Send the rob for write
assign rn2rob_rd_p_old = rat[id2rn_rd];
assign rn2rob_rd_p_new = next_free_reg;
assign rn2rob_valid = id2rn_valid && id2rn_rd_write;
assign rn2rob_pc = id2rn_pc;


// Status
assign no_free_reg = ~(|free_list);

endmodule