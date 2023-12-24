module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
// fs output state interface
wire        fs2ds_valid;
wire [64:0] fs2ds_bus;

// ds output state interface
wire         ds_allowin;
wire [ 32:0] br_zip;
wire         ds2es_valid;
wire [250:0] ds2es_bus;

// es output state interface
wire         es_allowin;
wire         es2ms_valid;
wire [122:0] es2ms_bus;
wire [ 39:0] es_rf_zip;

// ms output state interface
wire         ms_allowin;
wire         ms2ws_valid;
wire [149:0] ms2ws_bus;
wire [ 38:0] ms_rf_zip;
wire         ms_ex;

// ws output state interface
wire        ws_allowin;
wire [37:0] ws_rf_zip;
wire        csr_re;
wire [13:0] csr_num;
wire        csr_we;
wire [31:0] csr_wmask;
wire [31:0] csr_wvalue;
wire        ertn_flush;
wire        ws_ex; 
wire [31:0] ws_vaddr;
wire [31:0] ws_pc; 
wire [ 5:0] ws_ecode;
wire [ 8:0] ws_esubcode;

// csr output state interface
wire [31:0] csr_rvalue;
wire [31:0] ex_entry;
wire [31:0] ertn_entry;
wire        has_int;

IFreg my_ifReg(
    .clk(clk),
    .resetn(resetn),

    .inst_sram_en(inst_sram_en),
    .inst_sram_we(inst_sram_we),
    .inst_sram_addr(inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata),
    
    .fs2ds_valid(fs2ds_valid),
    .fs2ds_bus(fs2ds_bus),
    .ds_allowin(ds_allowin),
    .br_zip(br_zip),

    .ws_ex(ws_ex),
    .ertn_flush(ertn_flush),
    .ex_entry(ex_entry),
    .ertn_entry(ertn_entry)
);

IDreg my_idReg(
    .clk(clk),
    .resetn(resetn),

    .ds_allowin(ds_allowin),
    .br_zip(br_zip),
    .fs2ds_valid(fs2ds_valid),
    .fs2ds_bus(fs2ds_bus),

    .ds2es_valid(ds2es_valid),
    .ds2es_bus(ds2es_bus),
    .es_allowin(es_allowin),

    .ws_rf_zip(ws_rf_zip),
    .ms_rf_zip(ms_rf_zip),
    .es_rf_zip(es_rf_zip),

    .has_int(has_int),
    .ws_ex(ws_ex)
);

EXreg my_exReg(
    .clk(clk),
    .resetn(resetn),
    
    .es_allowin(es_allowin),
    .ds2es_valid(ds2es_valid),
    .ds2es_bus(ds2es_bus),

    .es2ms_valid(es2ms_valid),
    .es2ms_bus(es2ms_bus),
    .es_rf_zip(es_rf_zip),
    .ms_allowin(ms_allowin),
    
    .data_sram_en(data_sram_en),
    .data_sram_we(data_sram_we),
    .data_sram_addr(data_sram_addr),
    .data_sram_wdata(data_sram_wdata),

    .ms_ex(ms_ex),
    .ws_ex(ws_ex)
);

MEMreg my_memReg(
    .clk(clk),
    .resetn(resetn),

    .ms_allowin(ms_allowin),
    .es2ms_valid(es2ms_valid),
    .es2ms_bus(es2ms_bus),
    .es_rf_zip(es_rf_zip),

    .ms2ws_valid(ms2ws_valid),
    .ms2ws_bus(ms2ws_bus),
    .ms_rf_zip(ms_rf_zip),
    .ws_allowin(ws_allowin),

    .data_sram_rdata(data_sram_rdata),

    .ms_ex(ms_ex),
    .ws_ex(ws_ex)
) ;

WBreg my_wbReg(
    .clk(clk),
    .resetn(resetn),

    .ws_allowin(ws_allowin),
    .ms2ws_valid(ms2ws_valid),
    .ms2ws_bus(ms2ws_bus),
    .ms_rf_zip(ms_rf_zip),

    .debug_wb_pc(debug_wb_pc),
    .debug_wb_rf_we(debug_wb_rf_we),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),

    .ws_rf_zip(ws_rf_zip),

    .csr_re(csr_re),
    .csr_num(csr_num),
    .csr_we(csr_we),
    .csr_wmask(csr_wmask),
    .csr_wvalue(csr_wvalue),
    .ertn_flush(ertn_flush),
    .ws_ex(ws_ex),
    .ws_vaddr(ws_vaddr),
    .ws_pc(ws_pc),
    .ws_ecode(ws_ecode),
    .ws_esubcode(ws_esubcode),
    .csr_rvalue(csr_rvalue)
);

csr my_csr(
    .clk(clk),
    .resetn(resetn),

    .csr_rvalue(csr_rvalue),
    .csr_re(csr_re),

    .csr_num(csr_num),

    .csr_we(csr_we),
    .csr_wmask(csr_wmask),
    .csr_wvalue(csr_wvalue),

    .ex_entry(ex_entry),
    .ertn_entry(ertn_entry),
    .has_int(has_int),
    .ertn_flush(ertn_flush),
    .ws_ex(ws_ex),
    .ws_ecode(ws_ecode),
    .ws_esubcode(ws_esubcode),
    .ws_vaddr(ws_vaddr),
    .ws_pc(ws_pc)
);


endmodule
