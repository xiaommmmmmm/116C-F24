module RNMU(
    input wire clk,
    input wire rst,

    //input from register file
    //register1
    input wire [5:0] rs1_1,
    input wire [5:0] rs2_1,
    input wire [5:0] rd_1, //32bit---2^5
    input wire valid_1, //check register1 is valid

    //register2
    input wire [5:0] rs1_2,
    input wire [5:0] rs2_2,
    input wire [5:0] rd_2, //32bit---2^5
    input wire valid_2, //check register2 is valid

    //output of register file
    output wire [5:0] rename_rs1_1,
    output wire [5:0] rename_rs2_1,
    output wire [5:0] rename_rd_1,


    //ROB port
    input wire [5:0] rob_retire_valid, //check rob is valid, if yes, it can realease old register
    input wire [5:0] rob_retire_preg, //ROB retire的physical register


    //output to ROB
    output reg rename_stall, //check if need stall
    output reg [5:0] old_preg1,
    output reg [5:0] old_preg2,


    //Rat port
    reg [5:0] rat [0:31];    // 32个条目的RAT表，每个条目6位（因为物理寄存器有64个）

    //free pool
    reg [63:0] free_pool, //64 physcial registers,一共有64个寄存器，一一对应，reg[0]对应P0
    reg [6:0] free_count, //count how many free registers，一共要表示64个寄存器，所以需要7位



    always @(posedge clk or posedge rst) begin
    if (rst) begin
        free_pool <= {32'hFFFFFFFF, 32'h00000000};
        free_count = 32;

        integer i;
        for (i = 0; i < 32; i = i + 1) begin
            rat[i] <= i[5:0];
        end
    end


    else begin
        //if rob is valid, release the register
        if (rob_retire_valid) begin
            free_pool[rob_retire_preg] <= 1'b1;
            free_count <= free_count + 1;
        end

        //defacult not stall
        rename_stall <= 1'b0;

        //Operation for register1
        if (valid_1 && rd_1 !=0) begin
            reg found_1;              //label if found a free register for rd1
            found_1 = 1'b0;           //default not found
            old_preg1 <= rat[rd_1]    //映射关系

            integer i;
            for (i = 32; i < 64; i = i + 1) begin
                if (free_pool[i] == 1'b1 && !found_1) begin  //找到一个空闲的物理寄存器
                    free_pool[old_preg1] <= 1'b0;
                    rename_rd_1 <= i;
                    rat[rd_1] <= i;
                    free_count <= free_count - 1;
                    found_1 <= 1'b1;
                end
            end

            if (!found_1) begin
                rename_stall <= 1'b1;
            end
        end

        // 处理指令2 - 独立于指令1的处理
        if (valid_2 && rd_2 != 0) begin  // 不需要检查指令1的状态
            reg found_2;
            found_2 = 1'b0;
            
            old_preg_2 <= rat[rd_2];
            
            integer i;
            for (i = 32; i < 64; i = i + 1) begin
                if (free_pool[i] == 1'b1 && !found_2) begin
                    // 检查这个物理寄存器是否刚被指令1分配
                    if (!(valid_1 && rd_1 != 0 && found_1 && i == renamed_rd_1)) begin
                        free_pool[i] <= 1'b0;
                        renamed_rd_2 <= i;
                        rat[rd_2] <= i;
                        free_count <= free_count - 1;
                        found_2 = 1'b1;
                    end
                end
            end
            
            if (!found_2) begin
                rename_stall <= 1'b1;
            end
        end
    end

always @(*) begin
    if (rs1_1 == 0)
        renamed_rs1_1 = 6'd0;  // x0 dirct to P0
    else
        renamed_rs1_1 = rat[rs1_1];  
        
    if (rs2_1 == 0)
        renamed_rs2_1 = 6'd0;
    else
        renamed_rs2_1 = rat[rs2_1];

    if (rs1_2 == 0)
        renamed_rs1_2 = 6'd0;  // x0 dirct to P0
    else
        renamed_rs1_2 = rat[rs1_2];  
        
    if (rs2_1 == 0)
        renamed_rs2_2 = 6'd0;
    else
        renamed_rs2_2 = rat[rs2_2];
end

);
endmodule