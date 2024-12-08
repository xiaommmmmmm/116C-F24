module IDU(
    input wire clk,
    input wire rst_n,
    input wire [31:0] if2id_inst,    // Instruction from IFU
  	input wire [31:0] if2id_pc,             // Program counter from IFU
    input wire if2id_valid,          // Instruction valid from IFU
    
    // Decoded instruction fields
    output reg [4:0] id2rn_rd,       // Destination register
    output reg [4:0] id2rn_rs1,      // Source register 1
    output reg [4:0] id2rn_rs2,      // Source register 2
    output reg [31:0] id2iq_imm,     // Immediate value
    
    // Control signals
    output reg [6:0] id2iq_opcode,
    output reg id2iq_alu_src,        // 0: reg, 1: imm
    output reg id2iq_mem_read,       // Memory read enable
    output reg id2iq_mem_write,      // Memory write enable
    output reg id2iq_reg_write,      // Register write enable
    output reg [3:0] id2iq_alu_op,   // ALU operation
    output reg [1:0] id2iq_mem_size, // 00: byte, 10: word
    output reg id2iq_valid,           // Decoded instruction valid

    // Send PC to rename unit
    output reg [31:0] id2rn_pc

    // output reg control           // Combine all the control signal for use
);

// Parameters
parameter R_TYPE = 7'b0110011;  // ADD, XOR
parameter I_TYPE = 7'b0010011;  // ADDI, ORI, SRAI
parameter LOAD   = 7'b0000011;  // LB, LW
parameter STORE  = 7'b0100011;  // SB, SW
parameter LUI    = 7'b0110111;  // LUI

// ALU Operations
parameter ALU_ADD  = 4'b0000;
parameter ALU_XOR  = 4'b0001;
parameter ALU_OR   = 4'b0010;
parameter ALU_SRA  = 4'b0011;
parameter ALU_PASS = 4'b0100;

// Send PC to rename unit
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n)
        id2rn_pc <= 32'b0;
    else if (if2id_valid)
        id2rn_pc <= if2id_pc;
end

// Sequential decode logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        id2rn_rd <= 5'b0;
        id2rn_rs1 <= 5'b0;
        id2rn_rs2 <= 5'b0;
        id2iq_imm <= 32'b0;
        id2iq_alu_src <= 1'b0;
        id2iq_mem_read <= 1'b0;
        id2iq_mem_write <= 1'b0;
        id2iq_reg_write <= 1'b0;
        id2iq_alu_op <= ALU_ADD;
        id2iq_mem_size <= 2'b10;
        id2iq_valid <= 1'b0;
    end
    else if (if2id_valid) begin
        // Extract instruction fields
        id2iq_valid <= if2id_valid;
        id2iq_opcode <= if2id_inst[6:0];
        
        case (if2id_inst[6:0])  // current opcode
            R_TYPE: begin
                // R-type instruction decode
                id2rn_rd <= if2id_inst[11:7];
                id2rn_rs1 <= if2id_inst[19:15];
                id2rn_rs2 <= if2id_inst[24:20];
                id2iq_imm <= 32'b0;
                id2iq_alu_src <= 1'b0;
                id2iq_mem_read <= 1'b0;
                id2iq_mem_write <= 1'b0;
                id2iq_reg_write <= 1'b1;
                id2iq_mem_size <= 2'b10;
                
                case ({if2id_inst[31:25], if2id_inst[14:12]}) // Check func3 func7
                    10'b0000000_000: id2iq_alu_op <= ALU_ADD;  // ADD
                    10'b0000000_100: id2iq_alu_op <= ALU_XOR;  // XOR
                    default: id2iq_alu_op <= ALU_ADD;
                endcase
            end

            I_TYPE: begin
                // I-type instruction decode
                id2rn_rd <= if2id_inst[11:7];
                id2rn_rs1 <= if2id_inst[19:15];
                id2rn_rs2 <= 5'b0;
                id2iq_alu_src <= 1'b1;
                id2iq_mem_read <= 1'b0;
                id2iq_mem_write <= 1'b0;
                id2iq_reg_write <= 1'b1;
                id2iq_mem_size <= 2'b10;
                
                case (if2id_inst[14:12])
                    3'b000: begin  // ADDI
                        id2iq_alu_op <= ALU_ADD;
                        id2iq_imm <= {{20{if2id_inst[31]}}, if2id_inst[31:20]};
                    end
                    3'b110: begin  // ORI
                        id2iq_alu_op <= ALU_OR;
                        id2iq_imm <= {{20{if2id_inst[31]}}, if2id_inst[31:20]};
                    end
                    3'b101: begin  // SRAI
                        if (if2id_inst[31:26] == 6'b010000) begin
                            id2iq_alu_op <= ALU_SRA;
                            id2iq_imm <= {27'b0, if2id_inst[24:20]}; // shamt
                        end
                        else begin
                            id2iq_alu_op <= ALU_ADD;
                            id2iq_imm <= {{20{if2id_inst[31]}}, if2id_inst[31:20]};
                        end
                    end
                    default: begin
                        id2iq_alu_op <= ALU_ADD;
                        id2iq_imm <= {{20{if2id_inst[31]}}, if2id_inst[31:20]};
                    end
                endcase
            end

            LOAD: begin
                // Load instruction decode
                id2rn_rd <= if2id_inst[11:7];
                id2rn_rs1 <= if2id_inst[19:15];
                id2rn_rs2 <= 5'b0;
                id2iq_imm <= {{20{if2id_inst[31]}}, if2id_inst[31:20]};
                id2iq_alu_src <= 1'b1;
                id2iq_mem_read <= 1'b1;
                id2iq_mem_write <= 1'b0;
                id2iq_reg_write <= 1'b1;
                id2iq_alu_op <= ALU_ADD;
                id2iq_mem_size <= (if2id_inst[14:12] == 3'b000) ? 2'b00 : 2'b10;
            end

            STORE: begin
                // Store instruction decode
                id2rn_rd <= 5'b0;
                id2rn_rs1 <= if2id_inst[19:15];
                id2rn_rs2 <= if2id_inst[24:20];
                id2iq_imm <= {{20{if2id_inst[31]}}, if2id_inst[31:25], if2id_inst[11:7]};
                id2iq_alu_src <= 1'b1;
                id2iq_mem_read <= 1'b0;
                id2iq_mem_write <= 1'b1;
                id2iq_reg_write <= 1'b0;
                id2iq_alu_op <= ALU_ADD;
                id2iq_mem_size <= (if2id_inst[14:12] == 3'b000) ? 2'b00 : 2'b10;
            end

            LUI: begin
                // LUI instruction decode
                id2rn_rd <= if2id_inst[11:7];
                id2rn_rs1 <= 5'b0;
                id2rn_rs2 <= 5'b0;
                id2iq_imm <= {if2id_inst[31:12], 12'b0};
                id2iq_alu_src <= 1'b1;
                id2iq_mem_read <= 1'b0;
                id2iq_mem_write <= 1'b0;
                id2iq_reg_write <= 1'b1;
                id2iq_alu_op <= ALU_PASS;
                id2iq_mem_size <= 2'b10;
            end

            default: begin
                id2rn_rd <= 5'b0;
                id2rn_rs1 <= 5'b0;
                id2rn_rs2 <= 5'b0;
                id2iq_imm <= 32'b0;
                id2iq_alu_src <= 1'b0;
                id2iq_mem_read <= 1'b0;
                id2iq_mem_write <= 1'b0;
                id2iq_reg_write <= 1'b0;
                id2iq_alu_op <= ALU_ADD;
                id2iq_mem_size <= 2'b10;
                id2iq_valid <= 1'b0;
            end
        endcase
    end
    else begin
        id2iq_valid <= 1'b0;
    end
end



endmodule


module RNMU (
    input wire clk,
    input wire rst_n,
    
    // From id get the reg need to rename
    input wire id2rn_valid,             // Instruction is valid
    input wire [4:0] id2rn_rs1,         // Source register 1
    input wire [4:0] id2rn_rs2,         // Source register 2 
    input wire [4:0] id2rn_rd,          // Destination register
    input wire id2rn_rd_write,          // Register write enable (exclude the situation for store)
    input wire [31:0] id2rn_pc,         // Program counter
    
    // output to issue queue
    output wire [5:0] rn2iq_rs1_p,    // Physical register number for rs1
    output wire [5:0] rn2iq_rs2_p,    // Physical register number for rs2
    output wire [5:0] rn2iq_rd_p,     // Physical register number for rd

    // output to ROB about the renaming
    output wire [5:0] rn2rob_rd_p_old, // Original Physical register number for rd
    output wire [5:0] rn2rob_rd_p_new, // Renamed Physical register number for rd
    output wire rn2rob_valid, // rn2rob is valid
    output wire [31:0] rn2rob_pc, // Physical register number for rs1

    // Free list management
    output wire no_free_reg  // No free physical registers available
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
  	next_get_flag = 1'b0;
    for (i = 0; i < NUM_PHYS_REGS; i = i + 1) begin
      if (free_list[i] && (!next_get_flag) && (id2rn_rd != 5'b0)) begin
            next_free_reg = i;
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
            rat[k] <= k;
        end
        free_list <= {32'hFFFFFFFF, 32'h00000000};
    end
else if (id2rn_valid && id2rn_rd_write && ~no_free_reg) begin
        if (id2rn_rd != 5'b0) begin  // Don't rename r0
            rat[id2rn_rd] <= rn2iq_rd_p;
            free_list[rn2iq_rd_p] <= 1'b0;  // Mark as allocated
        end
    end
end

// Output renamed registers
assign rn2iq_rs1_p = (id2rn_rs1 == 5'b0) ? 6'b0 : rat[id2rn_rs1];
assign rn2iq_rs2_p = (id2rn_rs2 == 5'b0) ? 6'b0 : rat[id2rn_rs2];
assign rn2iq_rd_p = (id2rn_rd == 5'b0) ? 6'b0 : next_free_reg;

// Send the rob for write
assign rn2rob_rd_p_old = (id2rn_rd == 5'b0) ? 6'b0 : rat[id2rn_rd];
assign rn2rob_rd_p_new = (id2rn_rd == 5'b0) ? 6'b0 : next_free_reg;
assign rn2rob_valid = id2rn_valid && id2rn_rd_write && ~no_free_reg && (id2rn_rd != 5'b0);
assign rn2rob_pc = id2rn_pc;

// Status
assign no_free_reg = ~(|free_list);

endmodule

module IFU(
    input  wire clk,
    input  wire rst_n,
    output reg  [31:0] if2id_pc,
    output reg  [31:0] if2id_inst,
    output reg  if2id_valid
);

// if2id_instruction memory
reg [7:0] imem [0:1023]; // Byte-addressable
reg [31:0] if_pc;

// Increment the PC
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        if_pc <= 32'b0;
    else
        if_pc <= if_pc + 4;
end

// Read the instruction from memory
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        if2id_inst <= 32'b0;
        if2id_valid <= 1'b0;
    end 
    else begin
        if2id_inst <= {imem[if_pc], imem[if_pc+1], imem[if_pc+2], imem[if_pc+3]};
        if2id_valid <= 1'b1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        if2id_pc <= 32'b0;
    else
        if2id_pc <= if_pc;
end
endmodule

module ROB(
    input wire clk,
    input wire rst_n,

    // Fomr RNMU get the old destination register and renamed register number for id
    input wire [5:0] rn2rob_rd_p_old, // Original Physical register number for rd
    input wire [5:0] rn2rob_rd_p_new, // Renamed Physical register number for rd
    input wire [31:0] rn2rob_pc, // Physical register number for rs1
    input wire rn2rob_valid, // rn2rob is valid


    // From ISQ to check if ready
    input wire [5:0] iq2rob_scr1,
    input wire [5:0] iq2rob_scr2,
    input wire iq2rob_valid, // ISQ send the ready search is valid

    // Send to ISQ the scr1 status
    output wire rob2iq_scr1ready,
    output wire rob2iq_scr2ready,
    output wire [5:0] rob2iq_current_num, // Current ROB number
    output wire rob2iq_valid // rob scr1 scr2 ready search is valid
);

reg [45:0] rob[63:0];
reg [5:0] head_ptr;
integer i;

// renew the head_ptr
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n)
        head_ptr <= 6'b0;
    else if (head_ptr == 6'b111111 && rn2rob_valid)
        head_ptr <= 6'b0;
    else if (rn2rob_valid)
        head_ptr <= head_ptr + 1; // Increment the head_ptr
end

assign rob2iq_current_num = head_ptr; //Indicate the current write ROB number

// Write the ROB table 
always @ (posedge clk or negedge rst_n) begin
    for (i = 0; i < 64; i = i + 1) begin
        if (!rst_n)
            rob[i] <= 46'b0;
        else if ((i == head_ptr) && rn2rob_valid) begin
            rob[i][0] <= 1'b1;
            rob[i][6:1] <= rn2rob_rd_p_new;
            rob[i][12:7] <= rn2rob_rd_p_old;
            rob[i][44:13] <= rn2rob_pc;
            rob[i][45] <= 1'b0;
        end
    end
end

reg rob2iq_scr1use;
reg rob2iq_scr2use;

// Check if the scr1 and scr2 are ready and return back to the isq to write the reservation station
always @ (*) begin 
    rob2iq_scr1use = 1'b0;
    rob2iq_scr2use = 1'b0;
    for (i = 0; i < 64; i = i + 1) begin
      	if (rob[i][6:1] == iq2rob_scr1 && iq2rob_scr1 != 6'b0)
            rob2iq_scr1use = 1'b1;
    end
    for (i = 0; i < 64; i = i + 1) begin
      	if (rob[i][6:1] == iq2rob_scr2 && iq2rob_scr2 != 6'b0)
            rob2iq_scr2use = 1'b1;
    end
end

assign rob2iq_scr1ready = ~rob2iq_scr1use;
assign rob2iq_scr2ready = ~rob2iq_scr2use;


endmodule




module ISQ(
    input wire clk,
    input wire rst_n,
    
    // From RNU
    input wire [5:0] rn2iq_rs1_p,    // Physical register number for rs1
    input wire [5:0] rn2iq_rs2_p,    // Physical register number for rs2
    input wire [5:0] rn2iq_rd_p,     // Physical register number for rd
    input wire rn2iq_valid,          // Instruction is valid
    
    // Control signals from IDU
    input wire [6:0] id2iq_opcode,
    input wire id2iq_alu_src,        // 0: reg, 1: imm
    input wire id2iq_mem_read,       // Memory read enable
    input wire id2iq_mem_write,      // Memory write enable
    input wire id2iq_wire_write,     // Register write enable
    input wire [3:0] id2iq_alu_op,   // ALU operation
    input wire [1:0] id2iq_mem_size, // 00: byte, 10: word
    input wire id2iq_valid,          // Decoded instruction valid
    input wire [31:0] id2iq_imm,     // Immediate value

    // Verify the scr1 and scr2 ready status from ROB
    input wire rob2iq_scr1ready,
    input wire rob2iq_scr2ready,
  	input wire [5:0] rob2iq_current_num,   // Current ROB number

    // Function Unit ready status
    input wire alu2iq_ready1,
    input wire alu2iq_ready2,
    input wire mem2iq_ready,
    
    // Send the scr1 scr2 to ROB to check if ready
  	output wire [5:0] iq2rob_scr1,
  	output wire [5:0] iq2rob_scr2
);

// Parameters
parameter R_TYPE = 7'b0110011;  // ADD, XOR
parameter I_TYPE = 7'b0010011;  // ADDI, ORI, SRAI
parameter LOAD   = 7'b0000011;  // LB, LW
parameter STORE  = 7'b0100011;  // SB, SW
parameter LUI    = 7'b0110111;  // LUI

// Issue Queue Entry Structure
// Each entry should contain:
// [0]    - Valid bit
// [6:1]  - ROB number
// [12:7] - Destination register tag (rd)
// [18:13]- Source register 1 tag (rs1)
// [19]   - Source 1 ready bit
// [25:20]- Source register 2 tag (rs2)
// [26]   - Source 2 ready bit
// [58:27]- Immediate value
// [60:59]- Functional unit type (00: ALU1, 01: ALU2, 10: MEM)
// [67:61]- Opcode
// [68]   - ALU source
// [69]   - Memory read
// [70]   - Memory write
// [71]   - Register write
// [75:72]- ALU operation
// [77:76]- Memory size

reg [77:0] issue_queue[63:0];  // Modified width to store tags instead of data

// Find first free entry
reg [5:0] next_free_entry;
reg found_free;

integer i;
always @(*) begin
    found_free = 1'b0;
    next_free_entry = 6'd0;
    
    for (i = 0; i < 64; i = i + 1) begin
        if (!issue_queue[i][0] && !found_free) begin  // Check valid bit
            next_free_entry = i[5:0];
            found_free = 1'b1;
        end
    end
end

// Direct the source tags to ROB and get ready status
assign iq2rob_scr1 = rn2iq_rs1_p;
assign iq2rob_scr2 = rn2iq_rs2_p;

// ALU assignment toggle for RR
reg alu_assign;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        alu_assign <= 1'b0;
    else if ((id2iq_opcode == R_TYPE) || (id2iq_opcode == I_TYPE) || (id2iq_opcode == LUI))
        alu_assign <= ~alu_assign;
end

// Store instruction in issue queue
integer j;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (j = 0; j < 64; j = j + 1)
            issue_queue[j] <= 78'd0;
    end
    else if (rn2iq_valid & id2iq_valid & found_free) begin
        // Store tags and control signals
        issue_queue[next_free_entry][0] <= 1'b1;                    // Valid
        issue_queue[next_free_entry][6:1] <= rob2iq_current_num;    // ROB number
        issue_queue[next_free_entry][12:7] <= rn2iq_rd_p;          // rd tag
        issue_queue[next_free_entry][18:13] <= rn2iq_rs1_p;        // rs1 tag
        issue_queue[next_free_entry][19] <= rob2iq_scr1ready;      // rs1 ready
        issue_queue[next_free_entry][25:20] <= rn2iq_rs2_p;        // rs2 tag
        issue_queue[next_free_entry][26] <= rob2iq_scr2ready;      // rs2 ready
        issue_queue[next_free_entry][58:27] <= id2iq_imm;          // Immediate

        // Set functional unit type
        if (id2iq_opcode == R_TYPE || id2iq_opcode == I_TYPE || id2iq_opcode == LUI)
            issue_queue[next_free_entry][60:59] <= alu_assign ? 2'b01 : 2'b00;
        else if (id2iq_opcode == LOAD || id2iq_opcode == STORE)
            issue_queue[next_free_entry][60:59] <= 2'b10;

        // Store control signals
        issue_queue[next_free_entry][67:61] <= id2iq_opcode;
        issue_queue[next_free_entry][68] <= id2iq_alu_src;
        issue_queue[next_free_entry][69] <= id2iq_mem_read;
        issue_queue[next_free_entry][70] <= id2iq_mem_write;
        issue_queue[next_free_entry][71] <= id2iq_wire_write;
        issue_queue[next_free_entry][75:72] <= id2iq_alu_op;
        issue_queue[next_free_entry][77:76] <= id2iq_mem_size;
    end
end

// Update ready status when broadcasted on CDB
// Note: You'll need to add CDB interface signals to update ready bits
// This is a placeholder for where you would update ready bits when values
// are broadcasted on the Common Data Bus

endmodule
