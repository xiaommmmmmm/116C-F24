module instruction_fetch (
    input wire clk,
    input wire reset,
    input wire [31:0] total_instructions, // Actual number of instructions
    output reg [31:0] instruction1,
    output reg [31:0] instruction2,
    output reg valid
);

    reg [31:0] PC;
    reg done;
    reg [7:0] instruction_memory [0:1023]; // Example size for instruction memory

    initial begin
        PC = 0;
        done = 0;
        valid = 0;
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset logic
            PC <= 0;
            done <= 0;
            valid <= 0;
        end else if (!done) begin
            // Fetch two instructions per cycle
            if (PC < total_instructions * 4) begin
                instruction1 <= {instruction_memory[PC], instruction_memory[PC + 1], instruction_memory[PC + 2], instruction_memory[PC + 3]};
                if (PC + 4 < total_instructions * 4) begin 
                    instruction2 <= {instruction_memory[PC + 4], instruction_memory[PC + 5], instruction_memory[PC + 6], instruction_memory[PC + 7]};
                end else begin
                    instruction2 <= 32'b0; // NOP
                end
                valid <= 1;
            end else begin
                done <= 1;
                valid <= 0;
            end

            // Update PC to next pair of instructions
            PC <= PC + 8;
        end else begin
            // When done, issue NOPs
            instruction1 <= 32'b0;
            instruction2 <= 32'b0;
            valid <= 0;
        end
    end

endmodule
