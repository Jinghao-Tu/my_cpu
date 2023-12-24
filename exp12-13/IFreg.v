module IFreg(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire         inst_sram_en,
    output wire [ 3:0]  inst_sram_we,
    output wire [31:0]  inst_sram_addr,
    output wire [31:0]  inst_sram_wdata,
    input  wire [31:0]  inst_sram_rdata,
    // fs and ds state interface
    output wire         fs2ds_valid,
    output wire [64:0]  fs2ds_bus,  // {fs_except_adef, fs_pc, fs_inst}
    input  wire         ds_allowin,
    input  wire [32:0]  br_zip,     // {br_taken, br_target}
    // exception interface
    input  wire         ws_ex,
    input  wire         ertn_flush,
    input  wire [31:0]  ex_entry,
    input  wire [31:0]  ertn_entry
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire        br_taken;
wire [31:0] br_target;

reg  [31:0] fs_pc;
wire [31:0] fs_inst;

wire        fs_except_adef;

//------------------------------state control signal---------------------------------------
assign to_fs_valid  = resetn;
assign fs_ready_go  = 1'b1;
assign fs_allowin   = ~fs_valid | fs_ready_go & ds_allowin | ertn_flush | ws_ex;
assign fs2ds_valid  = fs_valid & fs_ready_go;
always @(posedge clk) begin
    if (~resetn) begin
        fs_valid <= 1'b0;
    end else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end
end


//------------------------------inst sram interface---------------------------------------    
assign inst_sram_en     = fs_allowin & to_fs_valid;
assign inst_sram_we     = 4'b0;
assign inst_sram_addr   = nextpc; // 因为取指令需要至少一个周期, 这样 fs_pc 和 fs_inst 在同一个周期上是对应的.
assign inst_sram_wdata  = 32'b0;
assign fs_inst          = fs_except_adef ? 32'h03400000 : inst_sram_rdata;  // NOP


//------------------------------pc relavant signals---------------------------------------    
assign seq_pc = fs_pc + 32'h4;
assign nextpc = ws_ex ? ex_entry :
                ertn_flush ? ertn_entry :
                br_taken ? br_target : seq_pc;

always @(posedge clk) begin
    if (~resetn) begin
        fs_pc <= 32'h1bfffffc;
    end else if (fs_allowin) begin
        fs_pc <= nextpc;
    end
end


//--------------------------exception interface--------------------------
assign fs_except_adef = (|fs_pc[1:0]) & fs_valid;


//------------------------------if and id state interface---------------------------------------
assign fs2ds_bus    = {fs_except_adef, fs_pc, fs_inst};
assign {br_taken, br_target} = br_zip;


endmodule
