module mycpu_top(
    input  wire        clk,     // 时钟信号
    input  wire        resetn,  // 复位信号 (低位有效)
    // inst sram interface
    output wire        inst_sram_we,    // 指令 内存 写使能
    output wire [31:0] inst_sram_addr,  // 指令 内存 地址
    output wire [31:0] inst_sram_wdata, // 指令 内存 写数据
    input  wire [31:0] inst_sram_rdata, // 指令 内存 读数据
    // data sram interface
    output wire        data_sram_we,    // 数据 内存 写使能
    output wire [31:0] data_sram_addr,  // 数据 内存 地址
    output wire [31:0] data_sram_wdata, // 数据 内存 写数据
    input  wire [31:0] data_sram_rdata, // 数据 内存 读数据
    // trace debug interface
    output wire [31:0] debug_wb_pc,         // 当前指令地址
    output wire [ 3:0] debug_wb_rf_we,      // 寄存器写使能
    output wire [ 4:0] debug_wb_rf_wnum,    // 寄存器写地址
    output wire [31:0] debug_wb_rf_wdata    // 寄存器写数据
);
reg         reset;                          // 复位信号 (高位有效)
always @(posedge clk) reset <= ~resetn;

reg         valid;                         // 有效指令标志
always @(posedge clk) begin
    if (reset) begin
        valid <= 1'b0;
    end
    else begin
        valid <= 1'b1;
    end
end

wire [31:0] seq_pc;     // 顺序执行的下一条指令地址, 也即 pc + 4
wire [31:0] nextpc;     // 下一条指令地址
wire        br_taken;   // 是否跳转
wire [31:0] br_target;  // 跳转目标地址
wire [31:0] inst;       // 当前指令
reg  [31:0] pc;         // 当前指令地址

wire [11:0] alu_op;         // ALU 操作码
wire        load_op;        // 是否是 load 指令
wire        src1_is_pc;     // src1 是否是 pc
wire        src2_is_imm;    // src2 是否是立即数
wire        res_from_mem;   // 结果是否来自内存
wire        dst_is_r1;      // 目标寄存器是否是 r1
wire        gr_we;          // 通用寄存器写使能
wire        mem_we;         // 内存写使能
wire        src_reg_is_rd;  // src2 是否是 rd
wire [4: 0] dest;           // 目标寄存器地址
wire [31:0] rj_value;       // rj 的值
wire [31:0] rkd_value;      // rk 或 rd 的值
wire [31:0] imm;            // 立即数
wire [31:0] br_offs;        // 跳转偏移量
wire [31:0] jirl_offs;      // jirl 偏移量
wire        rj_eq_rd;       // rj == rd ?

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
wire [25:0] i26;            // 指令 [ 9: 0] + [25:10], 26 位立即数

wire [63:0] op_31_26_d;     // 指令 [31:26] 解码结果
wire [15:0] op_25_22_d;     // 指令 [25:22] 解码结果
wire [ 3:0] op_21_20_d;     // 指令 [21:20] 解码结果
wire [31:0] op_19_15_d;     // 指令 [19:15] 解码结果

wire        inst_add_w;     // 000000 0000 01 00000 rk              rj  rd
wire        inst_sub_w;     // 000000 0000 01 00010 rk              rj  rd
wire        inst_slt;       // 000000 0000 01 00100 rk              rj  rd
wire        inst_sltu;      // 000000 0000 01 00101 rk              rj  rd
wire        inst_nor;       // 000000 0000 01 01000 rk              rj  rd
wire        inst_and;       // 000000 0000 01 01001 rk              rj  rd
wire        inst_or;        // 000000 0000 01 01010 rk              rj  rd
wire        inst_xor;       // 000000 0000 01 01011 rk              rj  rd
wire        inst_slli_w;    // 000000 0001 00 00001 ui5             rh  rd
wire        inst_srli_w;    // 000000 0001 00 01001 ui5             rh  rd
wire        inst_srai_w;    // 000000 0001 00 10001 ui5             rh  rd
wire        inst_addi_w;    // 000000 1010          si12            rj  rd
wire        inst_ld_w;      // 001010 0010          si12            rj  rd 
wire        inst_st_w;      // 001010 0110          si12            rj  rd
wire        inst_jirl;      // 010011               offset[15:0]    rj  rd
wire        inst_b;         // 010100               offset[15:0]    offset[25:16]
wire        inst_bl;        // 010101               offset[15:0]    offset[25:16]
wire        inst_beq;       // 010110               offset[15:0]    rj  rd
wire        inst_bne;       // 010111               offset[15:0]    rj  rd
wire        inst_lu12i_w;   // 000101 0             si20            rd

wire        need_ui5;       // 是否需要 ui5
wire        need_si12;      // 是否需要 si12
wire        need_si16;      // 是否需要 si16
wire        need_si20;      // 是否需要 si20
wire        need_si26;      // 是否需要 si26
wire        src2_is_4;      // src2 是否是 4

wire [ 4:0] rf_raddr1;      // 通用寄存器读地址 1
wire [31:0] rf_rdata1;      // 通用寄存器读数据 1
wire [ 4:0] rf_raddr2;      // 通用寄存器读地址 2
wire [31:0] rf_rdata2;      // 通用寄存器读数据 2
wire        rf_we   ;       // 通用寄存器写使能
wire [ 4:0] rf_waddr;       // 通用寄存器写地址
wire [31:0] rf_wdata;       // 通用寄存器写数据

wire [31:0] alu_src1   ;    // ALU 输入 1
wire [31:0] alu_src2   ;    // ALU 输入 2
wire [31:0] alu_result ;    // ALU 输出

wire [31:0] mem_result;     // 内存读数据
wire [31:0] final_result;   // 最终结果

assign seq_pc       = pc + 3'h4;    // 顺序执行的下一条指令地址
assign nextpc       = br_taken ? br_target : seq_pc;    // 下一条指令地址

always @(posedge clk) begin
    if (reset) begin
        pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else begin
        pc <= nextpc;
    end
end

assign inst_sram_we    = 1'b0;
assign inst_sram_addr  = pc;
assign inst_sram_wdata = 32'b0;
assign inst            = inst_sram_rdata;

assign op_31_26  = inst[31:26];
assign op_25_22  = inst[25:22];
assign op_21_20  = inst[21:20];
assign op_19_15  = inst[19:15];

assign rd   = inst[ 4: 0];
assign rj   = inst[ 9: 5];
assign rk   = inst[14:10];

assign i12  = inst[21:10];
assign i20  = inst[24: 5];
assign i16  = inst[25:10];
assign i26  = {inst[ 9: 0], inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w    // 加法
                    | inst_jirl | inst_bl;  
assign alu_op[ 1] = inst_sub_w;     // 减法
assign alu_op[ 2] = inst_slt;       // 小于
assign alu_op[ 3] = inst_sltu;      // 无符号小于
assign alu_op[ 4] = inst_and;       // 与
assign alu_op[ 5] = inst_nor;       // 或非
assign alu_op[ 6] = inst_or;        // 或
assign alu_op[ 7] = inst_xor;       // 异或
assign alu_op[ 8] = inst_slli_w;    // 逻辑左移
assign alu_op[ 9] = inst_srli_w;    // 逻辑右移
assign alu_op[10] = inst_srai_w;    // 算术右移
assign alu_op[11] = inst_lu12i_w;   // lu21i

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w;
assign need_si16  =  inst_jirl | inst_beq | inst_bne;
assign need_si20  =  inst_lu12i_w;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;

assign src1_is_pc    = inst_jirl | inst_bl;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;

assign res_from_mem  = inst_ld_w;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b; // 这里记录不用写的情况
assign mem_we        = inst_st_w;
assign dest          = dst_is_r1 ? 5'd1 : rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

assign rj_value  = rf_rdata1;
assign rkd_value = rf_rdata2;

assign rj_eq_rd = (rj_value == rkd_value);
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && valid;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);

assign alu_src1 = src1_is_pc  ? pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

alu u_alu(
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result)
    );

assign data_sram_we    = mem_we && valid;
assign data_sram_addr  = alu_result;
assign data_sram_wdata = rkd_value;

assign mem_result   = data_sram_rdata;
assign final_result = res_from_mem ? mem_result : alu_result;

assign rf_we    = gr_we && valid;
assign rf_waddr = dest;
assign rf_wdata = final_result;

// debug info generate
assign debug_wb_pc       = pc;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = dest;
assign debug_wb_rf_wdata = final_result;

// my debug signals
wire [31:0] debug_my_pc;
assign debug_my_pc = pc;
wire [31:0] debug_my_inst;
assign debug_my_inst = inst;

endmodule
