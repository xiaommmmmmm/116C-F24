module ROB(
    input wire clk,
    input wire rst_n,

    // Fomr RNMU get the old destination register and renamed register number for id
    input wire [5:0] rn2rob_rd_p_old, // Original Physical register number for rd
    input wire [5:0] rn2rob_rd_p_new, // Renamed Physical register number for rd
    input wire [31:0] rn2rob_pc, // Physical register number for rs1
    input wire rn2rob_valid, // rn2rob is valid


    // From ISQ to check if ready
    input wire iq2rob_scr1,
    input wire iq2rob_scr2,
    input wire iq2rob_valid, // ISQ send the ready search is valid

    // Send to ISQ the scr1 status
    output wire rob2iq_scr1ready,
    output wire rob2iq_scr2ready,
    output wire rob2iq_current_num, // Current ROB number
    output wire rob2iq_valid // rob scr1 scr2 ready search is valid
)

reg [45:0] rob[63:0];

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
    for (i = 0; i = 64; i = i + 1) begin
        if (!rst_n)
            rob[i] <= 46'b0;
        else if (i == head_ptr)
            rob[i] <= {1'b1, rn2rob_rd_p_old, rn2rob_rd_p_new, rn2rob_pc, 1'b0}
    end
end

// Check if the scr1 and scr2 are ready



