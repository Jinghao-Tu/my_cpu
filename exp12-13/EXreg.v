module EXreg(
    input  wire        clk,
    input  wire        resetn,
    // ds and es state interface
    output wire         es_allowin,
    input  wire         ds2es_valid,
    input  wire [250:0] ds2es_bus,
    // es and ms state interface
    output wire         es2ms_valid,
    output wire [122:0] es2ms_bus,
    output wire [39:0]  es_rf_zip, // {es_csr_re, es_res_from_mem, es_rf_we, es_rf_waddr, es_wdata}    
    input  wire         ms_allowin,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    // exception interface
    input  wire        ms_ex,
    input  wire        ws_ex
);

wire        es_ready_go;
reg         es_valid;
reg  [63:0] es_timer_cnt;

reg  [18:0] es_alu_op     ;
reg  [31:0] es_alu_src1   ;
reg  [31:0] es_alu_src2   ;
reg         es_res_from_mem;
reg         es_mem_re_s   ;
reg  [3 :0] es_mem_re     ;
reg  [3 :0] es_mem_we     ;
reg         es_csr_re     ;
reg         es_rf_we      ;
reg  [4 :0] es_rf_waddr   ;
reg  [31:0] es_rkd_value  ;
reg  [78:0] es_csr_zip    ;
reg  [ 1:0] es_cnt_zip    ;
reg  [ 5:0] es_except_zip_tmp;
reg  [31:0] es_pc         ;

wire        es_ex;
wire        es_except_ale;
wire [ 6:0] es_except_zip;

wire [31:0] es_alu_result ;
wire        es_alu_complete;
wire [31:0] es_rf_result_tmp;

wire        rd_cnt_h;
wire        rd_cnt_l;

//------------------------------state control signal---------------------------------------
assign es_ex        = |es_except_zip;
assign es_ready_go  = es_alu_complete | es_ex;  // 要么alu计算完成, 要么发生异常, 那就传递异常
assign es_allowin   = ~es_valid | es_ready_go & ms_allowin;     
assign es2ms_valid  = es_valid & es_ready_go;
always @(posedge clk) begin
    if(~resetn)
        es_valid <= 1'b0;
    else if (ws_ex) begin
        es_valid <= 1'b0;
    end else if (es_allowin)
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
        es_csr_re,          //1  bit
        es_rf_we,           //1  bit
        es_rf_waddr,        //5  bit
        es_rkd_value,       //32 bit
        es_csr_zip,         //79 bit
        es_cnt_zip,         //2  bit
        es_except_zip_tmp,  //6  bit
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
        es_csr_re,          //1  bit
        es_rf_we,           //1  bit
        es_rf_waddr,        //5  bit
        es_rkd_value,       //32 bit
        es_csr_zip,         //79 bit
        es_cnt_zip,         //2  bit
        es_except_zip_tmp,  //6  bit
        es_pc               //32 bit
        } <= ds2es_bus;
    end
end

assign {rd_cnt_h, rd_cnt_l} = es_cnt_zip;


//--------------------------es timer--------------------------
always @(posedge clk) begin
    if (~resetn) begin
        es_timer_cnt    <= 64'b0;
    end else begin
        es_timer_cnt    <= es_timer_cnt + 1'b1;
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
assign data_sram_en     = (|es_mem_re | |es_mem_we) & es_valid;
assign data_sram_we     = ({4{es_valid & ~ws_ex & ~ms_ex & ~es_ex}}) &
                        ( es_mem_we == 4'hf ? 4'hf
                        : es_mem_we == 4'h3 ? (es_alu_result[1] ? 4'hc : 4'h3)
                        : es_mem_we == 4'h1 ? (es_alu_result[1:0] == 2'b11 ? 4'h8 :
                                               es_alu_result[1:0] == 2'b10 ? 4'h4 :
                                               es_alu_result[1:0] == 2'b01 ? 4'h2 :
                                               es_alu_result[1:0] == 2'b00 ? 4'h1 : 4'h0)
                        : 4'h0);

assign data_sram_addr   = {es_alu_result[31:2], 2'b00};
assign data_sram_wdata  = es_mem_we == 4'h1 ? {es_rkd_value[7:0], es_rkd_value[7:0], es_rkd_value[7:0], es_rkd_value[7:0]}
                        : es_mem_we == 4'h3 ? {es_rkd_value[15:0], es_rkd_value[15:0]}
                        : es_mem_we == 4'hf ? {es_rkd_value[31:0]}
                        : 32'b0;


//--------------------------es and ms state interface--------------------------
assign es_except_ale = ((|es_alu_result[1:0]) & (es_mem_re == 4'hf | es_mem_we == 4'hf)
                      | (|es_alu_result[0]  ) & (es_mem_re == 4'h3 | es_mem_we == 4'h3)) & es_valid;

assign es_except_zip = {es_except_ale, es_except_zip_tmp};

assign es_rf_result_tmp = rd_cnt_h ? es_timer_cnt[63:32]
                        : rd_cnt_l ? es_timer_cnt[31: 0]
                        : es_alu_result;

assign es_rf_zip    = {es_csr_re & es_valid, es_res_from_mem & es_valid, es_rf_we & es_valid, es_rf_waddr, es_rf_result_tmp};  //认为es_rf_wdata等于es_rf_result_tmp, 需要特殊处理的, 在 ds_stall 阶段处理

assign es2ms_bus = {es_mem_re_s,        //1  bit
                    es_mem_re,          //4  bit
                    es_csr_zip,         //79 bit
                    es_except_zip,      //7  bit
                    es_pc               //32 bit
                    };

endmodule
