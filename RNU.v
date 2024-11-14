module RNU(
    input   clk,
    input   rd,
    output  old_reg,
    output  new_reg
);


// initial RAT and FREE LIST
reg [5:0] alias_table[31:0];
reg [5:0] free_list;

assign free_list[0] = 1'b0;

genvar i;

always @ (*) begin
    for (i=0; i<32; i++) begin
        if ((free_list[i] = 1) && (alias_table[rd] == 0) )
            alias_table[rd] = i;
            free_list[i] = 0;
        else
            alias_table[rd] = alias_table;
            free_list[i] = free_list[i];
    end
end


        