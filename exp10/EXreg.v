module EXreg(
    input  wire        clk,
    input  wire        resetn,
    // id and ex state interface
    output wire         es_allowin,
    input  wire         ds2es_valid,
    input  wire [154:0] ds2es_bus,
    // ex and mem state interface
    output wire        es2ms_valid,
    output reg  [31:0] es_pc,
    output wire [38:0] es_rf_zip, // {es_res_from_mem, es_rf_we, es_rf_waddr, es_wdata}    
    input  wire        ms_allowin,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata
);

wire        es_ready_go;
reg         es_valid;

reg  [18:0] es_alu_op     ;
reg  [31:0] es_alu_src1   ;
reg  [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ; 
wire        es_alu_complete;
reg  [31:0] es_rkd_value  ;
reg         es_res_from_mem;
reg         es_mem_we     ;
reg         es_rf_we      ;
reg  [4 :0] es_rf_waddr   ;


//------------------------------state control signal---------------------------------------
assign es_ready_go  = es_alu_complete;
assign es_allowin   = ~es_valid | es_ready_go & ms_allowin;     
assign es2ms_valid  = es_valid & es_ready_go;
always @(posedge clk) begin
    if(~resetn)
        es_valid <= 1'b0;
    else if (es_allowin)
        es_valid <= ds2es_valid; 
end


//------------------------------ds and es state interface---------------------------------------
always @(posedge clk) begin
    if (~resetn) begin
        {es_alu_op, es_res_from_mem, es_alu_src1, es_alu_src2, es_mem_we, es_rf_we, es_rf_waddr, es_rkd_value, es_pc} <= {155{1'b0}};
    end else if(ds2es_valid & es_allowin) begin
        {es_alu_op, es_res_from_mem, es_alu_src1, es_alu_src2, es_mem_we, es_rf_we, es_rf_waddr, es_rkd_value, es_pc} <= ds2es_bus;    
    end
end
    

//--------------------------alu part--------------------------
alu u_alu(
    .clk            (clk            ),
    .resetn         (resetn         ),
    .alu_op         (es_alu_op      ),
    .alu_src1       (es_alu_src1    ),
    .alu_src2       (es_alu_src2    ),
    .alu_result     (es_alu_result  ),
    .alu_complete   (es_alu_complete)
);


//--------------------------data sram interface--------------------------
assign data_sram_en     = (es_res_from_mem | es_mem_we) & es_valid;
assign data_sram_we     = {4{es_mem_we & es_valid}};
assign data_sram_addr   = es_alu_result;
assign data_sram_wdata  = es_rkd_value;


//--------------------------es and ms state interface--------------------------
assign es_rf_zip    = {es_res_from_mem & es_valid, es_rf_we & es_valid, es_rf_waddr, es_alu_result};  //暂时认为es_rf_wdata等于es_alu_result,只有在ld类指令需要特殊处理

endmodule
