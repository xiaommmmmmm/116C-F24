module ALU1(
    input wire clk,
    input wire rst_n,
    
    // Issue Interface
    input wire alu1_issue_valid,
    input wire [5:0] alu1_rd,           
    input wire [5:0] alu1_rob_num,      
    input wire [31:0] alu1_scr1_data,
    input wire [31:0] alu1_scr2_data,
    input wire [31:0] alu1_imm,
    input wire [3:0] alu1_op,
    input wire alu1_src_sel,
    input wire alu1_reg_write,
    output reg alu2iq_ready1,           
    
    // CDB Interface
    output reg cdb_request,             
    input wire cdb_grant,              
    output reg [5:0] cdb_tag,          
    output reg [31:0] cdb_data      
);

    // ALU Operations from IDU
    parameter ALU_ADD  = 4'b0000;
    parameter ALU_XOR  = 4'b0001;
    parameter ALU_OR   = 4'b0010;
    parameter ALU_SRA  = 4'b0011;
    parameter ALU_PASS = 4'b0100;

    // Internal signals
    reg [31:0] alu_result;
    reg busy;
    reg waiting_for_cdb;  // Indicates waiting for CDB access
    
    // Operand selection
    wire [31:0] operand_a = alu1_scr1_data;
    wire [31:0] operand_b = alu1_src_sel ? alu1_imm : alu1_scr2_data;
    
    // ALU Operation
    always @(*) begin
        case(alu1_op)
            ALU_ADD:  alu_result = operand_a + operand_b;
            ALU_XOR:  alu_result = operand_a ^ operand_b;
            ALU_OR:   alu_result = operand_a | operand_b;
            ALU_SRA:  alu_result = $signed(operand_a) >>> operand_b[4:0];
            ALU_PASS: alu_result = operand_b;
            default:  alu_result = 32'b0;
        endcase
    end
    
    // Control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            waiting_for_cdb <= 1'b0;
            cdb_request <= 1'b0;
            cdb_tag <= 6'b0;
            cdb_data <= 32'b0;
            alu2iq_ready1 <= 1'b1;
        end
        else begin
            if (alu1_issue_valid && !busy) begin
                // New instruction received
                busy <= 1'b1;
                alu2iq_ready1 <= 1'b0;
                waiting_for_cdb <= 1'b1;
                cdb_request <= 1'b1;
                cdb_tag <= alu1_rd;
                cdb_data <= alu_result;
            end
            else if (waiting_for_cdb) begin
                if (cdb_grant) begin
                    // CDB access granted, operation complete
                    waiting_for_cdb <= 1'b0;
                    busy <= 1'b0;
                    cdb_request <= 1'b0;
                    alu2iq_ready1 <= 1'b1;
                end
            end
        end
    end
endmodule

module ALU2(
    input wire clk,
    input wire rst_n,
    
    // Issue Interface
    input wire alu2_issue_valid,
    input wire [5:0] alu2_rd,
    input wire [5:0] alu2_rob_num,
    input wire [31:0] alu2_scr1_data,
    input wire [31:0] alu2_scr2_data,
    input wire [31:0] alu2_imm,
    input wire [3:0] alu2_op,
    input wire alu2_src_sel,
    input wire alu2_reg_write,
    output reg alu2iq_ready2,
    
    // CDB Interface
    output reg cdb_request,
    input wire cdb_grant,
    output reg [5:0] cdb_tag,
    output reg [31:0] cdb_data
);

    // ALU Operations from IDU
    parameter ALU_ADD  = 4'b0000;
    parameter ALU_XOR  = 4'b0001;
    parameter ALU_OR   = 4'b0010;
    parameter ALU_SRA  = 4'b0011;
    parameter ALU_PASS = 4'b0100;

    // Internal signals
    reg [31:0] alu_result;
    reg busy;
    reg waiting_for_cdb;
    
    // Operand selection
    wire [31:0] operand_a = alu2_scr1_data;
    wire [31:0] operand_b = alu2_src_sel ? alu2_imm : alu2_scr2_data;
    
    // ALU Operation
    always @(*) begin
        case(alu2_op)
            ALU_ADD:  alu_result = operand_a + operand_b;
            ALU_XOR:  alu_result = operand_a ^ operand_b;
            ALU_OR:   alu_result = operand_a | operand_b;
            ALU_SRA:  alu_result = $signed(operand_a) >>> operand_b[4:0];
            ALU_PASS: alu_result = operand_b;
            default:  alu_result = 32'b0;
        endcase
    end
    
    // Control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            waiting_for_cdb <= 1'b0;
            cdb_request <= 1'b0;
            cdb_tag <= 6'b0;
            cdb_data <= 32'b0;
            alu2iq_ready2 <= 1'b1;
        end
        else begin
            if (alu2_issue_valid && !busy) begin
                // New instruction received
                busy <= 1'b1;
                alu2iq_ready2 <= 1'b0;
                waiting_for_cdb <= 1'b1;
                cdb_request <= 1'b1;
                cdb_tag <= alu2_rd;
                cdb_data <= alu_result;
            end
            else if (waiting_for_cdb) begin
                if (cdb_grant) begin
                    // CDB access granted, operation complete
                    waiting_for_cdb <= 1'b0;
                    busy <= 1'b0;
                    cdb_request <= 1'b0;
                    alu2iq_ready2 <= 1'b1;
                end
            end
        end
    end
endmodule