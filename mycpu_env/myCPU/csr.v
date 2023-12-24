// control state regs
module csr (
    input  wire         clk,
    input  wire         resetn,
    // read port
    output wire [31:0]  csr_rvalue,
    input  wire         csr_re,
    // num port
    input  wire [13:0]  csr_num,
    // write port
    input  wire         csr_we,
    input  wire [31:0]  csr_wmask,
    input  wire [31:0]  csr_wvalue,
    // exception interface
    output wire [31:0]  ex_entry,
    output wire [31:0]  ertn_entry,
    output wire         has_int,
    input  wire         ertn_flush,
    input  wire         ws_ex,
    input  wire [ 5:0]  ws_ecode,
    input  wire [ 8:0]  ws_esubcode,
    input  wire [31:0]  ws_vaddr,
    input  wire [31:0]  ws_pc
);
wire [ 7:0] hw_int_in;
wire        ipi_int_in;
// crmd
wire        en_crmd = csr_num == 14'h0;
wire [31:0] crmd;
reg  [ 1:0] crmd_plv;
reg         crmd_ie;
reg         crmd_da;
reg         crmd_pg;
reg  [ 6:5] crmd_datf;
reg  [ 8:7] crmd_datm;

// prmd
wire        en_prmd = csr_num == 14'h1;
wire [31:0] prmd;
reg  [ 1:0] prmd_pplv;
reg         prmd_pie;

// ecfg
wire        en_ecfg = csr_num == 14'h4;
wire [31:0] ecfg;
reg  [12:0] ecfg_lie;    // ecfg_lie[10] = 0

// estat
wire         en_estat = csr_num == 14'h5;
wire [31: 0] estat;
reg  [12: 0] estat_is;    // estat_is[10] = 0
reg  [21:16] estat_ecode;
reg  [30:22] estat_esubcode;

// era
wire        en_era = csr_num == 14'h6;
wire [31:0] era;
reg  [31:0] era_pc;

// eerntry
wire        en_eentry = csr_num == 14'hc;
wire [31:0] eentry;
reg  [31:6] eentry_va;

// save-n, n=0-3
wire        en_save0 = csr_num == 14'h30;
wire        en_save1 = csr_num == 14'h31;
wire        en_save2 = csr_num == 14'h32;
wire        en_save3 = csr_num == 14'h33;
wire [31:0] save0;
wire [31:0] save1;
wire [31:0] save2;
wire [31:0] save3;
reg  [31:0] save0_data;
reg  [31:0] save1_data;
reg  [31:0] save2_data;
reg  [31:0] save3_data;

// badv
wire        en_badv = csr_num == 14'h7;
wire        ws_ex_addr_err;
wire [31:0] badv;
reg  [31:0] badv_vaddr;

// tid
wire        en_tid = csr_num == 14'h40;
wire [31:0] tid;
reg  [31:0] tid_tid;

// tcfg
wire        en_tcfg = csr_num == 14'h41;
wire [31:0] tcfg;
reg         tcfg_en;
reg         tcfg_periodic;
reg  [31:2] tcfg_initval;
wire [31:0] tcfg_next_value;

// tval
wire        en_tval = csr_num == 14'h42;
wire [31:0] tval;
reg  [31:0] tval_timeval;

// ticlr
wire        en_ticlr = csr_num == 14'h44;
wire [31:0] ticlr;
reg         ticlr_clr;  // 当对该 bit 写值 1, 将清除时钟中断标记. 该寄存器读出结果总为 0. 直接在 estat.is 中实现

//--------------------------output signals--------------------------
assign ex_entry     = eentry;
assign ertn_entry   = era;
assign has_int      = (|(estat_is[11:0] & ecfg_lie[11:0])) & crmd_ie;


//--------------------------crmd - plv ie--------------------------
always @(posedge clk) begin
    if (~resetn) begin
        crmd_plv    <= 2'b0;
        crmd_ie     <= 1'b0;
    end else if (ws_ex) begin
        crmd_plv    <= 2'b0;
        crmd_ie     <= 1'b0;
    end else if (ertn_flush) begin
        crmd_plv    <= prmd_pplv;
        crmd_ie     <= prmd_pie;
    end else if (csr_we && en_crmd) begin
        crmd_plv    <= csr_wmask[1:0] & csr_wvalue[1:0] | ~csr_wmask[1:0] & crmd_plv[1:0];
        crmd_ie     <= csr_wmask[2]   & csr_wvalue[2]   | ~csr_wmask[2]   & crmd_ie;
    end
end

//--------------------------crmd - da pg datf datm--------------------------
always @(posedge clk) begin
    if (~resetn) begin
        crmd_da     <= 1'b1;
        crmd_pg     <= 1'b0;
        crmd_datf   <= 2'b0;
        crmd_datm   <= 2'b0;
    end else if (ws_ex && ws_ecode == 6'h3f ) begin
        crmd_da     <= 1'b1;
        crmd_pg     <= 1'b0;
    end else if (ertn_flush && estat_ecode == 6'h3f) begin
        crmd_da     <= 1'b0;
        crmd_pg     <= 1'b1;
        crmd_datf   <= 2'b01;
        crmd_datm   <= 2'b01;
    end
end

//--------------------------prmd - pplv pie--------------------------
always @(posedge clk) begin
    if (~resetn) begin
        prmd_pplv   <= 2'b0;
        prmd_pie    <= 1'b0;
    end else if (ws_ex) begin
        prmd_pplv   <= crmd_plv;
        prmd_pie    <= crmd_ie;
    end else if (csr_we && en_prmd) begin
        prmd_pplv    <= csr_wmask[1:0] & csr_wvalue[1:0] | ~csr_wmask[1:0] & prmd_pplv[1:0];
        prmd_pie     <= csr_wmask[2]   & csr_wvalue[2]   | ~csr_wmask[2]   & prmd_pie;
    end
end

//--------------------------ecfg - lie--------------------------
always @(posedge clk) begin
    if (~resetn) begin
        ecfg_lie    <= 13'b0;
    end else if (csr_we && en_ecfg) begin
        ecfg_lie[9:0]   <= csr_wmask[9:0] & csr_wvalue[9:0] | ~csr_wmask[9:0] & ecfg_lie[9:0];
        ecfg_lie[10]    <= 1'b0;
        ecfg_lie[12:11] <= csr_wmask[12:11] & csr_wvalue[12:11] | ~csr_wmask[12:11] & ecfg_lie[12:11];
    end
end


//--------------------------estat - is--------------------------
assign hw_int_in    = 8'b0;
assign ipi_int_in   = 1'b0;
always @(posedge clk) begin
    if (~resetn) begin
        estat_is[1:0]   <= 2'b0;
    end else if (csr_we && en_estat) begin
        estat_is[1:0]   <= csr_wmask[1:0] & csr_wvalue[1:0] | ~csr_wmask[1:0] & estat_is[1:0];
    end

    estat_is[9:2]   <= hw_int_in[7:0];    // 硬中断
    estat_is[10]    <= 1'b0;    // 恒为0
    estat_is[11]    <= ~|tval_timeval ? 1'b1
                    : (csr_we && en_ticlr && csr_wmask[0] && csr_wvalue[0]) ? 1'b0
                    : estat_is[11];   // 定时器中断
    estat_is[12]    <= ipi_int_in;    // 核间中断
end


//--------------------------estat - ecode esubcode--------------------------
always @(posedge clk) begin
    if (~resetn) begin
        estat_ecode     <= 6'b0;
        estat_esubcode  <= 9'b0;
    end else if (ws_ex) begin
        estat_ecode     <= ws_ecode;
        estat_esubcode  <= ws_esubcode;
    end
end


//--------------------------era - pc--------------------------
always @(posedge clk) begin
    if (~resetn) begin
        era_pc  <=  32'b0;
    end else if (ws_ex) begin
        era_pc  <=  ws_pc;
    end else if (csr_we && en_era) begin
        era_pc  <=  csr_wmask[31:0] & csr_wvalue[31:0] | ~csr_wmask[31:0] & era_pc[31:0];
    end
end


//--------------------------eentry - va--------------------------
always @(posedge clk) begin
    if (~resetn) begin
        eentry_va   <= 26'b0;
    end else if (csr_we && en_eentry) begin
        eentry_va   <= csr_wmask[31:6] & csr_wvalue[31:6] | ~csr_wmask[31:6] & eentry_va[31:6];
    end
end


//--------------------------save0~3 - data --------------------------
always @(posedge clk) begin
    if (~resetn) begin
        save0_data  <= 32'b0;
        save1_data  <= 32'b0;
        save2_data  <= 32'b0;
        save3_data  <= 32'b0;
    end else if (csr_we && en_save0) begin
        save0_data  <= csr_wmask[31:0] & csr_wvalue[31:0] | ~csr_wmask[31:0] & save0_data[31:0];
    end else if (csr_we && en_save1) begin
        save1_data  <= csr_wmask[31:0] & csr_wvalue[31:0] | ~csr_wmask[31:0] & save1_data[31:0];
    end else if (csr_we && en_save2) begin
        save2_data  <= csr_wmask[31:0] & csr_wvalue[31:0] | ~csr_wmask[31:0] & save2_data[31:0];
    end else if (csr_we && en_save3) begin
        save3_data  <= csr_wmask[31:0] & csr_wvalue[31:0] | ~csr_wmask[31:0] & save3_data[31:0];
    end
end


//--------------------------badv - vaddr--------------------------
assign ws_ex_addr_err = ws_ecode == 6'h9 || ws_ecode == 6'h8;
always @(posedge clk) begin
    if (ws_ex && ws_ex_addr_err) begin
        badv_vaddr <= (ws_ecode == 6'h8 && ws_esubcode == 9'h0) ? ws_pc : ws_vaddr;
    end 
end


//--------------------------tid - tid--------------------------
always @(posedge clk) begin
    if (~resetn) begin
        tid_tid <= 32'b0;
    end else if (csr_we && en_tid) begin
        tid_tid <= csr_wmask[31:0] & csr_wvalue[31:0] | ~csr_wmask[31:0] & tid_tid[31:0];
    end
end


//--------------------------tcfg - en periodic initval--------------------------
always @(posedge clk) begin
    if (~resetn) begin
        tcfg_en         <= 1'b0;
    end else if (csr_we && en_tcfg) begin
        tcfg_en         <= csr_wmask[0]    & csr_wvalue[0]    | ~csr_wmask[0]    & tcfg_en           ;
        tcfg_periodic   <= csr_wmask[1]    & csr_wvalue[1]    | ~csr_wmask[1]    & tcfg_periodic     ;
        tcfg_initval    <= csr_wmask[31:2] & csr_wvalue[31:2] | ~csr_wmask[31:2] & tcfg_initval[31:2];
    end
end


//--------------------------tval - timeval--------------------------
assign tcfg_next_value = csr_wmask[31:0] & csr_wvalue[31:0] | ~csr_wmask[31:0] & tcfg[31:0];
always @(posedge clk) begin
    if (~resetn) begin
        tval_timeval <= 32'hffffffff;
    end else if (csr_we && en_tcfg && tcfg_next_value[0]) begin // 启动定时中断
        tval_timeval <= {tcfg_next_value[31:2], 2'b00};
    end else if (tcfg_en && tval_timeval != 32'hffffffff) begin
        if (~|tval_timeval && tcfg_periodic) begin // 循环
            tval_timeval <= {tcfg_initval, 2'b00};
        end else begin
            tval_timeval <= tval_timeval - 1'b1;
        end
    end
end


//--------------------------ticlr - clr--------------------------
always @(posedge clk) begin
    ticlr_clr <= 1'b0;
end


//--------------------------link csr wire and each regs--------------------------
assign crmd     = {23'b0, crmd_datm, crmd_datf, crmd_pg ,crmd_da, crmd_ie, crmd_plv};
assign prmd     = {29'b0, prmd_pie, prmd_pplv};
assign ecfg     = {19'b0, ecfg_lie};
assign estat    = {1'b0, estat_esubcode, estat_ecode, 3'b0, estat_is};
assign era      = era_pc;
assign eentry   = {eentry_va, 6'b0};
assign save0    = save0_data;
assign save1    = save1_data;
assign save2    = save2_data;
assign save3    = save3_data;
assign badv     = badv_vaddr;
assign tid      = tid_tid;
assign tcfg     = {tcfg_initval, tcfg_periodic, tcfg_en};
assign tval     = tval_timeval;
assign ticlr    = {31'b0, ticlr_clr};


//--------------------------csr_rvalue interface--------------------------
assign csr_rvalue = {32{en_crmd  }} & crmd
                  | {32{en_prmd  }} & prmd
                  | {32{en_ecfg  }} & ecfg
                  | {32{en_estat }} & estat
                  | {32{en_era   }} & era
                  | {32{en_eentry}} & eentry
                  | {32{en_save0 }} & save0
                  | {32{en_save1 }} & save1
                  | {32{en_save2 }} & save2
                  | {32{en_save3 }} & save3
                  | {32{en_badv  }} & badv
                  | {32{en_tid   }} & tid
                  | {32{en_tcfg  }} & tcfg
                  | {32{en_tval  }} & tval
                  | {32{en_ticlr }} & ticlr
                  ;

endmodule