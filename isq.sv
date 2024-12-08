module ISQ(
    input wire clk,
    input wire rst_n,
    
    // From RNU
    input wire [5:0] rn2iq_rs1_p,    // Physical register number for rs1
    input wire [5:0] rn2iq_rs2_p,    // Physical register number for rs2
    input wire [5:0] rn2iq_rd_p,     // Physical register number for rd
    input wire rn2iq_valid,          // Instruction is valid
    
    // Source operand data from RF
    input wire [31:0] rf2iq_scr1_data,  
    input wire [31:0] rf2iq_scr2_data,  
    
    // CDB Interface
    input wire cdb_valid,            
    input wire [5:0] cdb_tag,        
    input wire [31:0] cdb_data,      
    
    // Control signals from IDU
    input wire [6:0] id2iq_opcode,
    input wire id2iq_alu_src,        
    input wire id2iq_mem_read,       
    input wire id2iq_mem_write,      
    input wire id2iq_wire_write,     
    input wire [3:0] id2iq_alu_op,   
    input wire [1:0] id2iq_mem_size, 
    input wire id2iq_valid,          
    input wire [31:0] id2iq_imm,     

    // ROB Interface
    input wire rob2iq_scr1ready,
    input wire rob2iq_scr2ready,
    input wire [5:0] rob2iq_current_num,
    
    // Function Unit ready status
    input wire alu2iq_ready1,
    input wire alu2iq_ready2,
    input wire mem2iq_ready,
    
    // RF Interface
    output wire [5:0] iq2rf_rs1_addr,
    output wire [5:0] iq2rf_rs2_addr,
    
    // ROB Interface
    output wire [5:0] iq2rob_scr1,
    output wire [5:0] iq2rob_scr2,
    
    // Queue status
    output reg queue_full,
    
    // ALU1 Issue
    output reg alu1_issue_valid,
    output reg [5:0] alu1_rd,           
    output reg [5:0] alu1_rob_num,      
    output reg [31:0] alu1_scr1_data,
    output reg [31:0] alu1_scr2_data,
    output reg [31:0] alu1_imm,
    output reg [3:0] alu1_op,
    output reg alu1_src_sel,
    output reg alu1_reg_write,
    
    // ALU2 Issue
    output reg alu2_issue_valid,
    output reg [5:0] alu2_rd,
    output reg [5:0] alu2_rob_num,
    output reg [31:0] alu2_scr1_data,
    output reg [31:0] alu2_scr2_data,
    output reg [31:0] alu2_imm,
    output reg [3:0] alu2_op,
    output reg alu2_src_sel,
    output reg alu2_reg_write,
    
    // MEM Issue
    output reg mem_issue_valid,
    output reg [5:0] mem_rd,
    output reg [5:0] mem_rob_num,
    output reg [31:0] mem_scr1_data,
    output reg [31:0] mem_scr2_data,
    output reg [31:0] mem_imm,
    output reg mem_rd_en,
    output reg mem_wr_en,
    output reg [1:0] mem_size,
    output reg mem_reg_write
);

// Parameters
parameter R_TYPE = 7'b0110011;  // ADD, XOR
parameter I_TYPE = 7'b0010011;  // ADDI, ORI, SRAI
parameter LOAD   = 7'b0000011;  // LB, LW
parameter STORE  = 7'b0100011;  // SB, SW
parameter LUI    = 7'b0110111;  // LUI

// Issue Queue Entry Structure
// [0]    - Valid bit
// [6:1]  - ROB number
// [12:7] - Destination register tag (rd)
// [18:13]- Source register 1 tag (rs1)
// [19]   - Source 1 ready bit
// [51:20]- Source 1 data (32 bits)
// [57:52]- Source register 2 tag (rs2)
// [58]   - Source 2 ready bit
// [90:59]- Source 2 data (32 bits)
// [122:91]- Immediate value
// [124:123]- Functional unit type (00: ALU1, 01: ALU2, 10: MEM)
// [131:125]- Opcode
// [132]  - ALU source
// [133]  - Memory read
// [134]  - Memory write
// [135]  - Register write
// [139:136]- ALU operation
// [141:140]- Memory size

reg [141:0] issue_queue[63:0];

// Count valid entries for full status
reg [6:0] valid_count;
always @(*) begin
    valid_count = 7'd0;
    for (i = 0; i < 64; i = i + 1) begin
        valid_count = valid_count + {6'd0, issue_queue[i][0]};
    end
    queue_full = (valid_count == 7'd64);
end

// Connect RF read addresses
assign iq2rf_rs1_addr = rn2iq_rs1_p;
assign iq2rf_rs2_addr = rn2iq_rs2_p;

// ROB interface
assign iq2rob_scr1 = rn2iq_rs1_p;
assign iq2rob_scr2 = rn2iq_rs2_p;

// Find first free entry
reg [5:0] next_free_entry;
reg found_free;

integer i;
always @(*) begin
    found_free = 1'b0;
    next_free_entry = 6'd0;
    
    for (i = 0; i < 64; i = i + 1) begin
        if (!issue_queue[i][0] && !found_free) begin
            next_free_entry = i[5:0];
            found_free = 1'b1;
        end
    end
end

// ALU assignment toggle for RR
reg alu_assign;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        alu_assign <= 1'b0;
    else if ((id2iq_opcode == R_TYPE) || (id2iq_opcode == I_TYPE) || (id2iq_opcode == LUI))
        alu_assign <= ~alu_assign;
end

// Issue Logic for ALU1
reg [5:0] alu1_select;
reg alu1_found;

always @(*) begin
    alu1_issue_valid = 1'b0;
    alu1_select = 6'd0;
    alu1_found = 1'b0;
    
    for (i = 0; i < 64; i = i + 1) begin
        if (!alu1_found && 
            issue_queue[i][0] &&                     // Valid entry
            issue_queue[i][19] &&                    // RS1 ready
            issue_queue[i][58] &&                    // RS2 ready
            issue_queue[i][124:123] == 2'b00 &&      // ALU1 instruction
            alu2iq_ready1) begin                     // ALU1 is ready
            
            alu1_found = 1'b1;
            alu1_issue_valid = 1'b1;
            alu1_select = i[5:0];
        end
    end
    
    if (alu1_issue_valid) begin
        alu1_rd = issue_queue[alu1_select][12:7];
        alu1_rob_num = issue_queue[alu1_select][6:1];
        alu1_scr1_data = issue_queue[alu1_select][51:20];
        alu1_scr2_data = issue_queue[alu1_select][90:59];
        alu1_imm = issue_queue[alu1_select][122:91];
        alu1_op = issue_queue[alu1_select][139:136];
        alu1_src_sel = issue_queue[alu1_select][132];
        alu1_reg_write = issue_queue[alu1_select][135];
    end else begin
        alu1_rd = 6'd0;
        alu1_rob_num = 6'd0;
        alu1_scr1_data = 32'd0;
        alu1_scr2_data = 32'd0;
        alu1_imm = 32'd0;
        alu1_op = 4'd0;
        alu1_src_sel = 1'b0;
        alu1_reg_write = 1'b0;
    end
end

// Issue Logic for ALU2
reg [5:0] alu2_select;
reg alu2_found;

always @(*) begin
    alu2_issue_valid = 1'b0;
    alu2_select = 6'd0;
    alu2_found = 1'b0;
    
    for (i = 0; i < 64; i = i + 1) begin
        if (!alu2_found &&
            issue_queue[i][0] &&
            issue_queue[i][19] &&
            issue_queue[i][58] &&
            issue_queue[i][124:123] == 2'b01 &&      // ALU2 instruction
            alu2iq_ready2) begin
            
            alu2_found = 1'b1;
            alu2_issue_valid = 1'b1;
            alu2_select = i[5:0];
        end
    end
    
    if (alu2_issue_valid) begin
        alu2_rd = issue_queue[alu2_select][12:7];
        alu2_rob_num = issue_queue[alu2_select][6:1];
        alu2_scr1_data = issue_queue[alu2_select][51:20];
        alu2_scr2_data = issue_queue[alu2_select][90:59];
        alu2_imm = issue_queue[alu2_select][122:91];
        alu2_op = issue_queue[alu2_select][139:136];
        alu2_src_sel = issue_queue[alu2_select][132];
        alu2_reg_write = issue_queue[alu2_select][135];
    end else begin
        alu2_rd = 6'd0;
        alu2_rob_num = 6'd0;
        alu2_scr1_data = 32'd0;
        alu2_scr2_data = 32'd0;
        alu2_imm = 32'd0;
        alu2_op = 4'd0;
        alu2_src_sel = 1'b0;
        alu2_reg_write = 1'b0;
    end
end

// Issue Logic for MEM
reg [5:0] mem_select;
reg mem_found;

always @(*) begin
    mem_issue_valid = 1'b0;
    mem_select = 6'd0;
    mem_found = 1'b0;
    
    for (i = 0; i < 64; i = i + 1) begin
        if (!mem_found &&
            issue_queue[i][0] &&
            issue_queue[i][19] &&
            issue_queue[i][58] &&
            issue_queue[i][124:123] == 2'b10 &&      // MEM instruction
            mem2iq_ready) begin
            
            mem_found = 1'b1;
            mem_issue_valid = 1'b1;
            mem_select = i[5:0];
        end
    end
    
    if (mem_issue_valid) begin
        mem_rd = issue_queue[mem_select][12:7];
        mem_rob_num = issue_queue[mem_select][6:1];
        mem_scr1_data = issue_queue[mem_select][51:20];
        mem_scr2_data = issue_queue[mem_select][90:59];
        mem_imm = issue_queue[mem_select][122:91];
        mem_rd_en = issue_queue[mem_select][133];
        mem_wr_en = issue_queue[mem_select][134];
        mem_size = issue_queue[mem_select][141:140];
        mem_reg_write = issue_queue[mem_select][135];
end else begin                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              
        mem_rd = 6'd0;
        mem_rob_num = 6'd0;
        mem_scr1_data = 32'd0;
        mem_scr2_data = 32'd0;
        mem_imm = 32'd0;
        mem_rd_en = 1'b0;
        mem_wr_en = 1'b0;
        mem_size = 2'd0;
        mem_reg_write = 1'b0;
    end
end

// Queue Management Logic
integer j;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (j = 0; j < 64; j = j + 1)
            issue_queue[j] <= 142'd0;
    end
    else begin
        // Handle new instruction allocation
        if (rn2iq_valid & id2iq_valid & found_free) begin
            issue_queue[next_free_entry][0] <= 1'b1;                    // Valid
            issue_queue[next_free_entry][6:1] <= rob2iq_current_num;    // ROB number
            issue_queue[next_free_entry][12:7] <= rn2iq_rd_p;          // rd tag
            issue_queue[next_free_entry][18:13] <= rn2iq_rs1_p;        // rs1 tag
            issue_queue[next_free_entry][19] <= rob2iq_scr1ready;      // rs1 ready
            issue_queue[next_free_entry][51:20] <= rf2iq_scr1_data;    // rs1 data
            issue_queue[next_free_entry][57:52] <= rn2iq_rs2_p;        // rs2 tag
            issue_queue[next_free_entry][58] <= rob2iq_scr2ready;      // rs2 ready
            issue_queue[next_free_entry][90:59] <= rf2iq_scr2_data;    // rs2 data
            issue_queue[next_free_entry][122:91] <= id2iq_imm;         // Immediate

// Set functional unit type
            if (id2iq_opcode == R_TYPE || id2iq_opcode == I_TYPE || id2iq_opcode == LUI)
                issue_queue[next_free_entry][124:123] <= alu_assign ? 2'b01 : 2'b00;
            else if (id2iq_opcode == LOAD || id2iq_opcode == STORE)
                issue_queue[next_free_entry][124:123] <= 2'b10;

            // Store control signals
            issue_queue[next_free_entry][131:125] <= id2iq_opcode;
            issue_queue[next_free_entry][132] <= id2iq_alu_src;
            issue_queue[next_free_entry][133] <= id2iq_mem_read;
            issue_queue[next_free_entry][134] <= id2iq_mem_write;
            issue_queue[next_free_entry][135] <= id2iq_wire_write;
            issue_queue[next_free_entry][139:136] <= id2iq_alu_op;
            issue_queue[next_free_entry][141:140] <= id2iq_mem_size;
        end
        
        // Handle CDB updates
        if (cdb_valid) begin
            for (j = 0; j < 64; j = j + 1) begin
                if (issue_queue[j][0]) begin  // If entry is valid
                    // Check and update RS1
                    if (!issue_queue[j][19] &&           // If not ready
                        issue_queue[j][18:13] == cdb_tag) begin  // Tags match
                        issue_queue[j][19] <= 1'b1;      // Set ready
                        issue_queue[j][51:20] <= cdb_data;  // Update data
                    end
                    
                    // Check and update RS2
                    if (!issue_queue[j][58] &&           // If not ready
                        issue_queue[j][57:52] == cdb_tag) begin  // Tags match
                        issue_queue[j][58] <= 1'b1;      // Set ready
                        issue_queue[j][90:59] <= cdb_data;  // Update data
                    end
                end
            end
        end
        
        // Handle deallocation of issued instructions
        if (alu1_issue_valid) begin
            issue_queue[alu1_select][0] <= 1'b0;  // Clear valid bit
        end
        
        if (alu2_issue_valid) begin
            issue_queue[alu2_select][0] <= 1'b0;  // Clear valid bit
        end
        
        if (mem_issue_valid) begin
            issue_queue[mem_select][0] <= 1'b0;  // Clear valid bit
        end
    end
end

endmodule