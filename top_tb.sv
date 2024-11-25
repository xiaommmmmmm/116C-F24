`timescale 1ns/1ps

module top_tb();
    reg clk;
    reg rst_n;
    wire [31:0] inst;
    wire [31:0] pc;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Instantiate the top level
    TOP DUT(
        .clk(clk),
        .rst_n(rst_n),
        .pc(pc),
        .inst(inst)
    );
    
    // Test stimulus
    initial begin
        // Initialize memory from txt file
        $readmemh("r-test-hex.txt", DUT.IFU.imem);
        
        // Initialize
        rst_n = 1;
        
        // Apply reset
        #10 rst_n = 0;
        #10 rst_n = 1;
        
        // Monitor execution
        repeat(20) begin
            @(posedge clk) begin
                $display("\nCycle %0t:", $time);
                $display("PC: %0h", pc);
                $display("Instruction: %h", inst);
            end
        end
        
        #100 $finish;
    end

endmodule