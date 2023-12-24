module MEMreg(
    input  wire        clk,
    input  wire        resetn,
    // es and ms state interface
    output wire         ms_allowin,
    input  wire         es2ms_valid,
    input  wire [122:0] es2ms_bus,
    input  wire [ 39:0] es_rf_zip,
    // ms and ws state interface
    output wire         ms2ws_valid,
    output wire [149:0] ms2ws_bus,
    output wire [ 38:0] ms_rf_zip,   // {csr_re. ms_rf_we, ms_rf_waddr, ms_rf_wdata}
    input  wire         ws_allowin,
    // data sram interface
    input  wire [ 31:0] data_sram_rdata,
    // exception interface
    output wire         ms_ex,
    input  wire         ws_ex
);
wire        ms_ready_go;
reg         ms_valid;

reg         ms_csr_re     ;
reg         ms_res_from_mem;
reg         ms_rf_we      ;
reg  [4 :0] ms_rf_waddr   ;
reg  [31:0] ms_rf_result_tmp;
reg         ms_mem_re_s   ;
reg  [3 :0] ms_mem_re     ;
reg  [78:0] ms_csr_zip    ;
reg  [ 6:0] ms_except_zip ;
reg  [31:0] ms_pc         ;


wire [31:0] ms_rf_wdata   ;
wire [31:0] ms_mem_result ;

wire [32:0] shift_sram_rdata;

//------------------------------state control signal---------------------------------------
assign ms_ex        = (|ms_except_zip) & ms_valid;
assign ms_ready_go  = 1'b1;
assign ms_allowin   = ~ms_valid | ms_ready_go & ws_allowin;     
assign ms2ws_valid  = ms_valid & ms_ready_go;
always @(posedge clk) begin
    if(~resetn)
        ms_valid <= 1'b0;
    else if (ws_ex) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin)
        ms_valid <= es2ms_valid; 
end

//------------------------------es and ms state interface---------------------------------------
always @(posedge clk) begin
    if(~resetn) begin
       {ms_csr_re,          //1  bit
        ms_res_from_mem,    //1  bit
        ms_rf_we,           //1  bit
        ms_rf_waddr,        //5  bit
        ms_rf_result_tmp    //32 bit
        } <= 0;
       {ms_mem_re_s,        //1  bit
        ms_mem_re,          //4  bit
        ms_csr_zip,         //79 bit
        ms_except_zip,      //7  bit
        ms_pc               //32 bit
        }<= 0;
    end else if(es2ms_valid & ms_allowin) begin
       {ms_csr_re,          //1  bit
        ms_res_from_mem,    //1  bit
        ms_rf_we,           //1  bit
        ms_rf_waddr,        //5  bit
        ms_rf_result_tmp    //32 bit
        } <= es_rf_zip;
       {ms_mem_re_s,        //1  bit
        ms_mem_re,          //4  bit
        ms_csr_zip,         //79 bit
        ms_except_zip,      //7  bit
        ms_pc               //32 bit
        }<= es2ms_bus;
    end
end


//--------------------------data sram interface--------------------------
assign shift_sram_rdata = data_sram_rdata >>> {ms_rf_result_tmp[1:0], 3'b000}; // 不能 ms_alu_result[1:0]<<3, 因为只有2位, 所以只会是 2'b0.
assign ms_mem_result = ms_mem_re == 4'hf ? shift_sram_rdata
                     : ms_mem_re == 4'h3 ? {{16{ms_mem_re_s & shift_sram_rdata[15]}}, shift_sram_rdata[15:0]}
                     : ms_mem_re == 4'h1 ? {{24{ms_mem_re_s & shift_sram_rdata[ 7]}}, shift_sram_rdata[ 7:0]}
                     : 32'b0;
                    

//--------------------------ms and ws state--------------------------
assign ms_rf_wdata  = ms_res_from_mem ? ms_mem_result : ms_rf_result_tmp;
assign ms_rf_zip = {ms_csr_re & ms_valid, ms_rf_we & ms_valid, ms_rf_waddr, ms_rf_wdata};
assign ms2ws_bus = {ms_rf_result_tmp,   //32 bit
                    ms_csr_zip,         //79 bit
                    ms_except_zip,      //7  bit
                    ms_pc               //32 bit
                    };


endmodule