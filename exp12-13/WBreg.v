module WBreg(
    input  wire        clk,
    input  wire        resetn,
    // ms and ws state interface
    output wire         ws_allowin,
    input  wire         ms2ws_valid,
    input  wire [149:0] ms2ws_bus,
    input  wire [ 38:0] ms_rf_zip,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    // ds and ws state interface
    output wire [37:0] ws_rf_zip,   // {ws_rf_we, ws_rf_waddr, ws_rf_wdata}
    // ws and csr state interface
    output wire         csr_re,
    output wire [13:0]  csr_num,
    output wire         csr_we,
    output wire [31:0]  csr_wmask,
    output wire [31:0]  csr_wvalue,
    output wire         ertn_flush,
    output wire         ws_ex,
    output reg  [31:0]  ws_vaddr,
    output reg  [31:0]  ws_pc,
    output wire [ 5:0]  ws_ecode,
    output wire [ 8:0]  ws_esubcode,
    input  wire [31:0]  csr_rvalue
);
    
wire        ws_ready_go;
reg         ws_valid;

reg         ws_csr_re;
wire        ws_rf_we;
reg  [4 :0] ws_rf_waddr;
wire [31:0] ws_rf_wdata;
reg  [78:0] ws_csr_zip;
reg  [ 6:0] ws_except_zip;

reg         ws_rf_we_tmp;
reg  [31:0] ws_rf_wdata_tmp;

wire        ws_except_adef;
wire        ws_except_ale;
wire        ws_except_sys;
wire        ws_except_brk;
wire        ws_except_ine;
wire        ws_except_int;

reg  [ 1:0] ertn_cnt;    // ertn 到 ertn 返回的指令之间有 4 条错误指令, 因此需要屏蔽他们, 方法是拉低 ws_valid 四个周期, 自动排空错误指令.
reg         en_ertn_cnt;
//------------------------------state control signal---------------------------------------
assign ws_ready_go      = 1'b1;
assign ws_allowin       = ~ws_valid | ws_ready_go ;     
always @(posedge clk) begin
    if(~resetn) begin
        ws_valid <= 1'b0;
        en_ertn_cnt <= 1'b0;
        ertn_cnt    <= 2'b0;
    end else if (ws_ex) begin
        ws_valid <= 1'b0;
    end else if (ertn_flush) begin
        ws_valid <= 1'b0;
        ertn_cnt <= 2'b11;
        en_ertn_cnt <= 1'b1;
    end else if (en_ertn_cnt) begin
        if (~|ertn_cnt) begin
            ws_valid <= ms2ws_valid;
            en_ertn_cnt <= 1'b0;
        end else begin
            ertn_cnt = ertn_cnt - 1'b1;
        end
    end else if (ws_allowin)
        ws_valid <= ms2ws_valid;
end


//------------------------------mem and wb state interface---------------------------------------
always @(posedge clk) begin
    if (~resetn) begin
       {ws_vaddr,
        ws_csr_zip,
        ws_except_zip,
        ws_pc
        } <= 0;
       {ws_csr_re,
        ws_rf_we_tmp,
        ws_rf_waddr,
        ws_rf_wdata_tmp
        } <= 0;
    end else if(ms2ws_valid & ws_allowin) begin
       {ws_vaddr,
        ws_csr_zip,
        ws_except_zip,
        ws_pc
        } <= ms2ws_bus;
       {ws_csr_re,
        ws_rf_we_tmp,
        ws_rf_waddr,
        ws_rf_wdata_tmp
        } <= ms_rf_zip;
    end
end


//--------------------------ws and csr state interface--------------------------
assign csr_re = ws_csr_re;
assign {csr_num, csr_wmask, csr_wvalue, csr_we} = ws_csr_zip & {79{ws_valid}};
assign {ws_except_ale, ws_except_adef, ws_except_ine, ws_except_int, ws_except_brk, ws_except_sys, ertn_flush} = ws_except_zip;
assign ws_ex = (ws_except_ale | ws_except_adef | ws_except_ine | ws_except_int | ws_except_brk | ws_except_sys) & ws_valid;
assign {ws_ecode, ws_esubcode}  = ws_except_int  ? {6'h0, 9'h0}
                                : ws_except_adef ? {6'h8, 9'h0}
                                : ws_except_ale  ? {6'h9, 9'h0}
                                : ws_except_sys  ? {6'hb, 9'h0}
                                : ws_except_brk  ? {6'hc, 9'h0}
                                : ws_except_ine  ? {6'hd, 9'h0}
                                : 6'h0;

//------------------------------id and wb state interface---------------------------------------
assign ws_rf_wdata  = ws_csr_re ? csr_rvalue : ws_rf_wdata_tmp;
assign ws_rf_we     = ws_rf_we_tmp & ws_valid & ~ws_ex;
assign ws_rf_zip    = {ws_rf_we & ws_valid, ws_rf_waddr, ws_rf_wdata};


//------------------------------trace debug interface---------------------------------------
assign debug_wb_pc = ws_pc;
assign debug_wb_rf_wdata = ws_rf_wdata;
assign debug_wb_rf_we = {4{ws_rf_we & ws_valid}};
assign debug_wb_rf_wnum = ws_rf_waddr;


endmodule
