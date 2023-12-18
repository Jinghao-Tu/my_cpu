module EXreg(
    input  wire        clk,
    input  wire        resetn,
    // id and ex state interface
    output wire        ex_allowin,
    input  wire [5 :0] id_rf_zip, // {id_rf_we, id_rf_waddr}
    input  wire        id_to_ex_valid,
    input  wire [31:0] id_pc,    
    input  wire [75:0] id_alu_data_zip, // {ex_alu_op, ex_alu_src1, ex_alu_src2}
    input  wire        id_res_from_mem, 
    input  wire        id_mem_we,
    input  wire [31:0] id_rkd_value,
    // ex and mem state interface
    input  wire        mem_allowin,
    output reg  [5 :0] ex_rf_zip, // {ex_rf_we, ex_rf_waddr}
    output wire        ex_to_mem_valid,
    output reg  [31:0] ex_pc,    
    output wire [31:0] ex_alu_result, 
    output reg         ex_res_from_mem, 
    output reg         ex_mem_we,
    output reg  [31:0] ex_rkd_value
);

wire        ex_ready_go;
reg         ex_valid;

reg  [11:0] ex_alu_op;
reg  [31:0] ex_alu_src1   ;
reg  [31:0] ex_alu_src2   ;


//------------------------------state control signal---------------------------------------
assign ex_ready_go      = 1'b1;
assign ex_allowin       = ~ex_valid | ex_ready_go & mem_allowin;     
assign ex_to_mem_valid  = ex_valid & ex_ready_go;
always @(posedge clk) begin
    if(~resetn)
        ex_valid <= 1'b0;
    else
        ex_valid <= id_to_ex_valid & ex_allowin; 
end


//------------------------------id and ex state interface---------------------------------------
always @(posedge clk) begin
    if(id_to_ex_valid & ex_allowin)
        ex_pc <= id_pc;
end
always @(posedge clk) begin
    if(id_to_ex_valid & ex_allowin)
        {ex_alu_op, ex_alu_src1, ex_alu_src2} <= id_alu_data_zip;
end
always @(posedge clk) begin
    if(id_to_ex_valid & ex_allowin)
        {ex_res_from_mem, ex_mem_we, ex_rkd_value, ex_rf_zip} <= {id_res_from_mem, id_mem_we, id_rkd_value, id_rf_zip};
end
    
alu u_alu(
    .alu_op     (ex_alu_op    ),
    .alu_src1   (ex_alu_src1  ),
    .alu_src2   (ex_alu_src2  ),
    .alu_result (ex_alu_result)
);


endmodule
