module EXreg(
    input  wire        clk,
    input  wire        resetn,
    // ds and es state interface
    output wire         es_allowin,
    output wire [38:0]  es_rf_zip, // {es_res_from_mem, es_rf_we, es_rf_waddr, es_wdata}    
    input  wire         ds2es_valid,
    input  wire [162:0] ds2es_bus,
    // es and ms state interface
    output wire        es2ms_valid,
    output wire [75:0] es2ms_bus,
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
reg  [31:0] es_rkd_value  ;
reg         es_res_from_mem;
reg         es_mem_re_s   ;
reg  [3 :0] es_mem_re     ;
reg  [3 :0] es_mem_we     ;
reg         es_rf_we      ;
reg  [4 :0] es_rf_waddr   ;
reg  [31:0] es_pc;

wire [31:0] es_alu_result ;
wire        es_alu_complete;
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
        {es_alu_op,          //19 bit
         es_alu_src1,        //32 bit
         es_alu_src2,        //32 bit
         es_res_from_mem,    //1  bit
         es_mem_re_s,        //1  bit
         es_mem_re,          //4  bit
         es_mem_we,          //4  bit
         es_rf_we,           //1  bit
         es_rf_waddr,        //5  bit
         es_rkd_value,       //32 bit
         es_pc               //32 bit
         } <= 0;
    end else if(ds2es_valid & es_allowin) begin
       {es_alu_op,          //19 bit
        es_alu_src1,        //32 bit
        es_alu_src2,        //32 bit
        es_res_from_mem,    //1  bit
        es_mem_re_s,        //1  bit
        es_mem_re,          //4  bit
        es_mem_we,          //4  bit
        es_rf_we,           //1  bit
        es_rf_waddr,        //5  bit
        es_rkd_value,       //32 bit
        es_pc               //32 bit
        } <= ds2es_bus;
    end
end
    
assign es_rf_zip    = {es_res_from_mem & es_valid, es_rf_we & es_valid, es_rf_waddr, es_alu_result};  //认为es_rf_wdata等于es_alu_result, 只有在ld类指令需要特殊处理, 在 ds_stall 阶段处理

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
assign data_sram_en     = (|es_mem_re | |es_mem_we) & es_valid;
assign data_sram_we     = es_mem_we == 4'hf ? 4'hf
                        : es_mem_we == 4'h3 ? (es_alu_result[1] ? 4'hc : 4'h3)
                        : es_mem_we == 4'h1 ? (es_alu_result[1:0] == 2'b11 ? 4'h8 :
                                               es_alu_result[1:0] == 2'b10 ? 4'h4 :
                                               es_alu_result[1:0] == 2'b01 ? 4'h2 :
                                               es_alu_result[1:0] == 2'b00 ? 4'h1 : 4'h0)
                        : 4'h0;

assign data_sram_addr   = es_alu_result; // automatically fit the %4 condition
assign data_sram_wdata  = es_mem_we == 4'h1 ? {es_rkd_value[7:0], es_rkd_value[7:0], es_rkd_value[7:0], es_rkd_value[7:0]}
                        : es_mem_we == 4'h3 ? {es_rkd_value[15:0], es_rkd_value[15:0]}
                        : es_mem_we == 4'hf ? {es_rkd_value[31:0]}
                        : 32'b0;


//--------------------------es and ms state interface--------------------------
assign es2ms_bus = {es_res_from_mem,    //1  bit
                    es_mem_re_s,        //1  bit
                    es_mem_re,          //4  bit
                    es_rf_we,           //1  bit
                    es_rf_waddr,        //5  bit
                    es_alu_result,      //32 bit
                    es_pc               //32 bit
                };

endmodule
