module IDreg(
    input  wire         clk,
    input  wire         resetn,
    // fs and ds state interface
    output wire         ds_allowin,
    output wire [32:0]  br_zip,     // {br_taken, br_target}
    input  wire         fs2ds_valid,
    input  wire [63:0]  fs2ds_bus,  // {fs_pc, fs_inst}
    // ds and es state interface
    output wire         ds2es_valid,
    output wire [162:0] ds2es_bus,
    input  wire         es_allowin,
    // each instruction's wb request from ex, mem and wb
    input  wire [37:0]  ws_rf_zip,  // {ws_rf_we, ws_rf_waddr, ws_rf_wdata}
    input  wire [37:0]  ms_rf_zip,  // {ms_rf_we, ms_rf_waddr, ms_rf_wdata}
    input  wire [38:0]  es_rf_zip   // {es_res_from_mem, es_rf_we, es_rf_waddr, es_alu_result}
);
// ds state signals
wire        ds_ready_go;
reg         ds_valid;
reg  [31:0] ds_inst;
reg  [31:0] ds_pc;
wire        ds_stall;
// ds output (almost to es) signals, also including ds_pc, but it's not defined here.
wire [18:0] ds_alu_op;
wire        ds_res_from_mem;
wire        ds_mem_re_s;
wire [31:0] ds_alu_src1;
wire [31:0] ds_alu_src2;
wire [ 3:0] ds_mem_we;
wire [ 3:0] ds_mem_re;
wire        ds_rf_we;
wire [ 4:0] ds_rf_waddr;
wire [31:0] ds_rkd_value;
// decode flag signals
wire [18:0] alu_op;
wire [31:0] alu_src1;
wire [31:0] alu_src2;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        mem_re_s;
wire [ 3:0] mem_we;
wire [ 3:0] mem_re;
wire        dst_is_r1;
wire        gr_we;
wire        src_reg_is_rd;
wire        rj_eq_rd;
wire        rj_lt_rd;
wire        rj_lt_rd_s;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;
// decode date signals
wire [ 5:0] op_31_26;       // 指令 [31:26]
wire [ 3:0] op_25_22;       // 指令 [25:22]
wire [ 1:0] op_21_20;       // 指令 [21:20]
wire [ 4:0] op_19_15;       // 指令 [19:15]
wire [ 4:0] rd;             // 指令 [ 4: 0], rd
wire [ 4:0] rj;             // 指令 [ 9: 5], rj
wire [ 4:0] rk;             // 指令 [14:10], rk
wire [11:0] i12;            // 指令 [21:10], 12 位立即数
wire [19:0] i20;            // 指令 [24: 5], 20 位立即数
wire [15:0] i16;            // 指令 [25:10], 16 位立即数
wire [25:0] i26;            // 指令 [ 9: 0] + [25:10], 26 位
// these are used to decode instructions' func
wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;
// decode instructions signals
wire        inst_add_w;     // 000000 0000 01 00000 rk              rj  rd
wire        inst_sub_w;     // 000000 0000 01 00010 rk              rj  rd
wire        inst_slt;       // 000000 0000 01 00100 rk              rj  rd
wire        inst_sltu;      // 000000 0000 01 00101 rk              rj  rd
wire        inst_nor;       // 000000 0000 01 01000 rk              rj  rd
wire        inst_and;       // 000000 0000 01 01001 rk              rj  rd
wire        inst_or;        // 000000 0000 01 01010 rk              rj  rd
wire        inst_xor;       // 000000 0000 01 01011 rk              rj  rd
wire        inst_slli_w;    // 000000 0001 00 00001 ui5             rj  rd
wire        inst_srli_w;    // 000000 0001 00 01001 ui5             rj  rd
wire        inst_srai_w;    // 000000 0001 00 10001 ui5             rj  rd
wire        inst_addi_w;    // 000000 1010          si12            rj  rd
wire        inst_ld_w;      // 001010 0010          si12            rj  rd 
wire        inst_st_w;      // 001010 0110          si12            rj  rd
wire        inst_jirl;      // 010011               offset[15:0]    rj  rd
wire        inst_b;         // 010100               offset[15:0]    offset[25:16]
wire        inst_bl;        // 010101               offset[15:0]    offset[25:16]
wire        inst_beq;       // 010110               offset[15:0]    rj  rd
wire        inst_bne;       // 010111               offset[15:0]    rj  rd
wire        inst_lu12i_w;   // 000101 0             si20                rd
wire        inst_slti;      // 000000 1000          si12            rj  rd
wire        inst_sltui;     // 000000 1001          si12            rj  rd
wire        inst_andi;      // 000000 1101          ui12            rj  rd
wire        inst_ori;       // 000000 1110          ui12            rj  rd
wire        inst_xori;      // 000000 1111          ui12            rj  rd
wire        inst_sll_w;     // 000000 0000 01 01110 rk              rj  rd
wire        inst_srl_w;     // 000000 0000 01 01111 rk              rj  rd
wire        inst_sra_w;     // 000000 0000 01 10000 rk              rj  rd
wire        inst_pcaddu12i; // 000111 0             si20                rd
wire        inst_mul_w;     // 000000 0000 01 11000 rk              rj  rd
wire        inst_mulh_w;    // 000000 0000 01 11001 rk              rj  rd
wire        inst_mulh_wu;   // 000000 0000 01 11010 rk              rj  rd
wire        inst_div_w;     // 000000 0000 10 00000 rk              rj  rd
wire        inst_mod_w;     // 000000 0000 10 00001 rk              rj  rd
wire        inst_div_wu;    // 000000 0000 10 00010 rk              rj  rd
wire        inst_mod_wu;    // 000000 0000 10 00011 rk              rj  rd
wire        inst_blt;       // 011000               offset[15:0]    rj  rd
wire        inst_bge;       // 011001               offset[15:0]    rj  rd
wire        inst_bltu;      // 011010               offset[15:0]    rj  rd
wire        inst_bgeu;      // 011011               offset[15:0]    rj  rd
wire        inst_ld_b;      // 001010 0000          si12            rj  rd
wire        inst_ld_h;      // 001010 0001          si12            rj  rd
wire        inst_ld_bu;     // 001010 1000          si12            rj  rd
wire        inst_ld_hu;     // 001010 1001          si12            rj  rd
wire        inst_st_b;      // 001010 0100          si12            rj  rd
wire        inst_st_h;      // 001010 0101          si12            rj  rd
// decode imm signals
wire        need_ui5;
wire        need_ui12;
wire        need_si12;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;
// decode jump signals
wire        br_taken;
wire [31:0] br_target;

wire        rf_we;
wire [ 4:0] rf_waddr;
wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        conflict_r1_wb;
wire        conflict_r2_wb;
wire        conflict_r1_mem;
wire        conflict_r2_mem;
wire        conflict_r1_ex;
wire        conflict_r2_ex;
wire        need_r1;
wire        need_r2;

wire        ws_rf_we;
wire [ 4:0] ws_rf_waddr;
wire [31:0] ws_rf_wdata;
wire        ms_rf_we;
wire [ 4:0] ms_rf_waddr;
wire [31:0] ms_rf_wdata;
wire        es_res_from_mem;
wire        es_rf_we;
wire [ 4:0] es_rf_waddr;
wire [31:0] es_rf_wdata;


//------------------------------state control signal---------------------------------------
assign ds_ready_go  = ~ds_stall;
assign ds_allowin   = ~ds_valid | ds_ready_go & es_allowin;     
assign ds2es_valid  = ds_valid & ds_ready_go;
assign ds_stall     = es_res_from_mem & (conflict_r1_ex & need_r1 | conflict_r2_ex & need_r2);  // 只有 LD 的 RAW 情况需要阻塞
always @(posedge clk) begin
    if(~resetn)
        ds_valid <= 1'b0;
    else if (br_taken) begin
        ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs2ds_valid ; 
    end
end


//------------------------------fs and ds state interface---------------------------------------
always @(posedge clk) begin
    if (~resetn) begin
        {ds_pc, ds_inst} <= 64'h0;
    end else if (fs2ds_valid & ds_allowin) begin
        {ds_pc, ds_inst} <= fs2ds_bus;
    end
end


//--------------------------b and j instructions--------------------------
assign rj_eq_rd = (rj_value == rkd_value);
assign rj_lt_rd = (rj_value <  rkd_value);
assign rj_lt_rd_s = rj_value[31] ^ rkd_value[31] ? rj_value[31] : rj_lt_rd;
assign br_taken = (inst_beq  &&  rj_eq_rd
                || inst_bne  && !rj_eq_rd
                || inst_jirl
                || inst_bl
                || inst_b
                || inst_blt  &&  rj_lt_rd_s
                || inst_bge  && !rj_lt_rd_s && !rj_eq_rd
                || inst_bltu &&  rj_lt_rd
                || inst_bgeu && !rj_lt_rd   && !rj_eq_rd
                ) && ds_valid;
assign br_target = (inst_beq || inst_bne || inst_bl   || inst_b 
                 || inst_blt || inst_bge || inst_bltu || inst_bgeu) ? (ds_pc + br_offs) :
                                                /*inst_jirl*/ (rj_value + jirl_offs);
assign br_zip   = {br_taken, br_target};

//------------------------------decode instruction---------------------------------------
assign op_31_26  = ds_inst[31:26];
assign op_25_22  = ds_inst[25:22];
assign op_21_20  = ds_inst[21:20];
assign op_19_15  = ds_inst[19:15];

assign rd   = ds_inst[ 4: 0];
assign rj   = ds_inst[ 9: 5];
assign rk   = ds_inst[14:10];

assign i12  = ds_inst[21:10];
assign i20  = ds_inst[24: 5];
assign i16  = ds_inst[25:10];
assign i26  = {ds_inst[ 9: 0], ds_inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt         = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor         = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and         = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or          = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor         = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w      = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w      = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w      = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w      = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w        = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w        = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl        = op_31_26_d[6'h13];
assign inst_b           = op_31_26_d[6'h14];
assign inst_bl          = op_31_26_d[6'h15];
assign inst_beq         = op_31_26_d[6'h16];
assign inst_bne         = op_31_26_d[6'h17];
assign inst_lu12i_w     = op_31_26_d[6'h05] & ~ds_inst[25];
assign inst_slti        = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui       = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_andi        = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori         = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori        = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_sll_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_pcaddu12i   = op_31_26_d[6'h07] & ~ds_inst[25];
assign inst_mul_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_div_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_mod_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_div_wu      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_wu      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
assign inst_blt         = op_31_26_d[6'h18];
assign inst_bge         = op_31_26_d[6'h19];
assign inst_bltu        = op_31_26_d[6'h1a];
assign inst_bgeu        = op_31_26_d[6'h1b];
assign inst_ld_b        = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h        = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_bu       = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu       = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_st_b        = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h        = op_31_26_d[6'h0a] & op_25_22_d[4'h5];

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w | inst_jirl | inst_bl |
                    inst_pcaddu12i | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltui;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll_w;
assign alu_op[ 9] = inst_srli_w | inst_srl_w;
assign alu_op[10] = inst_srai_w | inst_sra_w;
assign alu_op[11] = inst_lu12i_w;
assign alu_op[12] = inst_mul_w;
assign alu_op[13] = inst_mulh_w;
assign alu_op[14] = inst_mulh_wu;
assign alu_op[15] = inst_div_w;
assign alu_op[16] = inst_div_wu;
assign alu_op[17] = inst_mod_w;
assign alu_op[18] = inst_mod_wu;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_ui12  =  inst_andi | inst_ori | inst_xori;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w | inst_slti | inst_sltui
                    |inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h;
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
             need_ui12 ? {20'b0, i12[11:0]}         :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                            {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w | inst_st_b | inst_st_h
                     | inst_blt | inst_bge | inst_bltu | inst_bgeu;

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm  =   inst_slli_w     | inst_srli_w     |
                        inst_srai_w     | inst_addi_w     |
                        inst_ld_w       | inst_st_w       |
                        inst_lu12i_w    | inst_jirl       |
                        inst_bl         | inst_slti       |
                        inst_sltui      | inst_andi       |
                        inst_ori        | inst_xori       |
                        inst_pcaddu12i  | inst_ld_b       |
                        inst_ld_h       | inst_ld_bu      |
                        inst_ld_hu      | inst_st_b       |
                        inst_st_h
                        ;

assign alu_src1 = src1_is_pc  ? ds_pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

assign res_from_mem = |mem_re;
assign mem_re_s = inst_ld_w | inst_ld_b | inst_ld_h;

assign dst_is_r1    = inst_bl;
assign gr_we        = ~inst_st_w & ~inst_st_b & ~inst_st_h & ~inst_beq & ~inst_bne
                    & ~inst_b & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu; 
assign mem_re       = inst_ld_w ? 4'hf
                    : inst_ld_b | inst_ld_bu ? 4'h1
                    : inst_ld_h | inst_ld_hu ? 4'h3 : 4'h0;
assign mem_we       = inst_st_w ? 4'hf
                    : inst_st_b ? 4'h1
                    : inst_st_h ? 4'h3 : 4'h0;
assign dest         = dst_is_r1 ? 5'd1 : rd;


//------------------------------regfile control---------------------------------------
assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
assign rf_we    = gr_we ; 
assign rf_waddr = dest; 
// wb reqquests 
assign {ws_rf_we, ws_rf_waddr, ws_rf_wdata}  = ws_rf_zip;
assign {ms_rf_we, ms_rf_waddr, ms_rf_wdata}  = ms_rf_zip;
assign {es_res_from_mem, es_rf_we, es_rf_waddr, es_rf_wdata} = es_rf_zip;
regfile u_regfile(
.clk    (clk        ),
.raddr1 (rf_raddr1  ),
.rdata1 (rf_rdata1  ),
.raddr2 (rf_raddr2  ),
.rdata2 (rf_rdata2  ),
.we     (ws_rf_we   ),
.waddr  (ws_rf_waddr),
.wdata  (ws_rf_wdata)
);
assign conflict_r1_wb   = (|rf_raddr1) & (rf_raddr1 == ws_rf_waddr) & ws_rf_we;
assign conflict_r2_wb   = (|rf_raddr2) & (rf_raddr2 == ws_rf_waddr) & ws_rf_we;
assign conflict_r1_mem  = (|rf_raddr1) & (rf_raddr1 == ms_rf_waddr) & ms_rf_we;
assign conflict_r2_mem  = (|rf_raddr2) & (rf_raddr2 == ms_rf_waddr) & ms_rf_we;
assign conflict_r1_ex   = (|rf_raddr1) & (rf_raddr1 == es_rf_waddr) & es_rf_we;
assign conflict_r2_ex   = (|rf_raddr2) & (rf_raddr2 == es_rf_waddr) & es_rf_we;
assign need_r1          = ~src1_is_pc  & (|alu_op);
assign need_r2          = ~src2_is_imm & (|alu_op);
assign rj_value  =  conflict_r1_ex  ? es_rf_wdata :
                    conflict_r1_mem ? ms_rf_wdata :
                    conflict_r1_wb  ? ws_rf_wdata : rf_rdata1;
assign rkd_value =  conflict_r2_ex  ? es_rf_wdata :
                    conflict_r2_mem ? ms_rf_wdata :
                    conflict_r2_wb  ? ws_rf_wdata : rf_rdata2;


//--------------------------id and ex state interface--------------------------
assign {ds_alu_op,          //19 bit
        ds_alu_src1,        //32 bit
        ds_alu_src2,        //32 bit
        ds_res_from_mem,    //1  bit
        ds_mem_re_s,        //1  bit
        ds_mem_re,          //4  bit
        ds_mem_we,          //4  bit
        ds_rf_we,           //1  bit
        ds_rf_waddr,        //5  bit
        ds_rkd_value        //32 bit
        }
        =
       {alu_op,          //19 bit
        alu_src1,        //32 bit
        alu_src2,        //32 bit
        res_from_mem,    //1  bit
        mem_re_s,    //1  bit
        mem_re,          //4  bit
        mem_we,          //4  bit
        rf_we,           //1  bit
        rf_waddr,        //5  bit
        rkd_value        //32 bit
        };
assign ds2es_bus = {ds_alu_op,          //19 bit
                    ds_alu_src1,        //32 bit
                    ds_alu_src2,        //32 bit
                    ds_res_from_mem,    //1  bit
                    ds_mem_re_s,        //1  bit
                    ds_mem_re,          //4  bit
                    ds_mem_we,          //4  bit
                    ds_rf_we,           //1  bit
                    ds_rf_waddr,        //5  bit
                    ds_rkd_value,       //32 bit
                    ds_pc               //32 bit
                    };


endmodule
