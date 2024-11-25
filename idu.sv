module IDU(
    input wire clk,
    input wire rst_n,
    input wire [31:0] if2id_inst,    // Instruction from IFU
    input wire if2id_pc,             // Program counter from IFU
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