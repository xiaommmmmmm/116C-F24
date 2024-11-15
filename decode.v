module decode (
    input wire clk,
    input wire reset,
    input wire valid,
    input wire [31:0] instruction1,
    input wire [31:0] instruction2,
    output reg [4:0] src_reg1_1, src_reg2_1, dest_reg_1, // Source and destination registers for instruction 1
    output reg [4:0] src_reg1_2, src_reg2_2, dest_reg_2, // Source and destination registers for instruction 2
    output reg [6:0] opcode_1, opcode_2,                  // Opcode for both instructions
    output reg [2:0] funct3_1, funct3_2,                  // funct3 for both instructions
    output reg [6:0] funct7_1, funct7_2,                  // funct7 for both instructions (R-type)
    output reg l_flag_1, s_flag_1,                      // Load/store flags for instruction 1
    output reg l_flag_2, s_flag_2,                      // Load/store flags for instruction 2
    output reg [31:0] immediate_1, immediate_2            // Immediate values for both instructions
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all outputs
            src_reg1_1 <= 0;
            src_reg2_1 <= 0;
            dest_reg_1 <= 0;
            opcode_1 <= 0;
            funct3_1 <= 0;
            funct7_1 <= 0;
            l_flag_1 <= 0;
            s_flag_1 <= 0;
            immediate_1 <= 0;

            src_reg1_2 <= 0;
            src_reg2_2 <= 0;
            dest_reg_2 <= 0;
            opcode_2 <= 0;
            funct3_2 <= 0;
            funct7_2 <= 0;
            l_flag_2 <= 0;
            s_flag_2 <= 0;
            immediate_2 <= 0;
        end else if (valid) begin
            /* Instructions: 
            R-type: ADD, XOR, SRAI(rs2->shamt)
            I-type: ADDI, ORI, LB, LW,
            U-type: LUI, 
            S-type: SB, SW
            */
            // Decode instruction 1
            opcode_1 <= instruction1[6:0];     // Opcode field
            l_flag_1 <= (instruction1[6:0] == 7'b0000011); // Check if load  (LW, LB)
            s_flag_1 <= (instruction1[6:0] == 7'b0100011); // Check if store  (SW, SB)
            funct3_1 <= instruction1[14:12];   // funct3 field
            funct7_1 <= instruction1[31:25];   // funct7 field (for R-type)
            src_reg1_1 <= instruction1[19:15]; // rs1
            src_reg2_1 <= instruction1[24:20]; // rs2
            dest_reg_1 <= instruction1[11:7];  // rd
            
            // Decode additional fields based on instruction type
            // Decode additional fields based on instruction type
            case (opcode_1)
                7'b0110111: begin // U-type (LUI)
                    immediate_1 <= {instruction1[31:12], 12'b0};
                end
                7'b0010011: begin // I-type (e.g., ORI, ADDI ) & R-type(SRAI)
                    if (funct3_1 == 3'b101 && funct7_1 == 7'b0100000) begin // SRAI
                        immediate_1 <= {27'b0, instruction1[24:20]};
                    end else begin
                        immediate_1 <= {{20{instruction1[31]}}, instruction1[31:20]}; // Sign-extend immediate for I-type
                    end
                end
                7'b0000011: begin // I-type (e.g., LB, LW)
                    immediate_1 <= {{20{instruction1[31]}}, instruction1[31:20]};
                end
                7'b0100011: begin // S-type (e.g., SB, SW)
                    immediate_1 <= {{20{instruction1[31]}}, instruction1[31:25], instruction1[11:7]};
                end
                7'b0110011: begin // R-type (e.g., ADD, XOR)
                    immediate_1 <= 0;
                end
                default: begin
                    immediate_1 <= 0;
                end
            endcase

            // Decode instruction 2
            opcode_2 <= instruction2[6:0];     // Opcode field
            l_flag_2 <= (instruction2[6:0] == 7'b0000011); // Check if load word (LW)
            s_flag_2 <= (instruction2[6:0] == 7'b0100011); // Check if store word (SW)
            
            // Decode additional fields based on instruction type
            opcode_2 <= instruction2[6:0];     // Opcode field
            lw_flag_2 <= (instruction2[6:0] == 7'b0000011); // Check if load  (LW, LB)
            sw_flag_2 <= (instruction2[6:0] == 7'b0100011); // Check if store  (SW, SB)
            funct3_2 <= instruction2[14:12];   // funct3 field
            funct7_2 <= instruction2[31:25];   // funct7 field (for R-type)
            src_reg1_2 <= instruction2[19:15]; // rs1
            src_reg2_2 <= instruction2[24:20]; // rs2
            dest_reg_2 <= instruction2[11:7];  // rd
            
            // Decode additional fields based on instruction type
            case (opcode_2)
                7'b0110111: begin // U-type (LUI)
                    immediate_2 <= {instruction2[31:12], 12'b0};
                end
                7'b0010011: begin // I-type (e.g., ORI, ADDI ) & R-type(SRAI)
                    if (funct3_2 == 3'b101 && funct7_2 == 7'b0100000) begin // SRAI
                        immediate_2 <= {27'b0, instruction2[24:20]};
                    end else begin
                        immediate_2 <= {{20{instruction2[31]}}, instruction2[31:20]}; // Sign-extend immediate for I-type
                    end
                end
                7'b0000011: begin // I-type (e.g., LB, LW)
                    immediate_2 <= {{20{instruction2[31]}}, instruction2[31:20]};
                end
                7'b0100011: begin // S-type (e.g., SB, SW)
                    immediate_2 <= {{20{instruction2[31]}}, instruction2[31:25], instruction2[11:7]};
                end
                7'b0110011: begin // R-type (e.g., ADD, XOR)
                    immediate_2 <= 0;
                end
                default: begin
                    immediate_2 <= 0;
                end
            endcase
        end
    end

endmodule