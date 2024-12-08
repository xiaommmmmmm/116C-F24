module PhysicalRF(
    input wire clk,
    input wire rst_n,
    
    // Read ports for Issue Queue
    input wire [5:0] iq2rf_rs1_addr,      // RS1 read address
    input wire [5:0] iq2rf_rs2_addr,      // RS2 read address
    output reg [31:0] rf2iq_scr1_data,    // RS1 read data
    output reg [31:0] rf2iq_scr2_data,    // RS2 read data
    
    // Write port from CDB
    input wire cdb_valid,                  // Write enable from CDB
    input wire [5:0] cdb_tag,             // Write address from CDB
    input wire [31:0] cdb_data            // Write data from CDB
);

// Register file storage (64 physical registers x 32 bits each)
reg [31:0] phys_regs [63:0];

// Read logic - combinational
always @(*) begin
    // Read port 1
    rf2iq_scr1_data = phys_regs[iq2rf_rs1_addr];
    
    // Read port 2
    rf2iq_scr2_data = phys_regs[iq2rf_rs2_addr];
end

// Write logic
integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers to 0
        for (i = 0; i < 64; i = i + 1) begin
            phys_regs[i] <= 32'd0;
        end
    end
    else begin
        // Write from CDB
        if (cdb_valid) begin
            phys_regs[cdb_tag] <= cdb_data;
        end
    end
end

endmodule