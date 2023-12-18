module IFreg(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire         inst_sram_en,
    output wire [ 3:0]  inst_sram_we,
    output wire [31:0]  inst_sram_addr,
    output wire [31:0]  inst_sram_wdata,
    input  wire [31:0]  inst_sram_rdata,
    // if and id state interface
    input  wire         id_allowin,
    input  wire         br_taken,
    input  wire [31:0]  br_target,
    output wire         if_to_id_valid,
    output wire [31:0]  if_inst,
    output reg  [31:0]  if_pc
);

wire         if_ready_go;
wire         if_allowin;
reg          if_valid;
wire [31:0]  seq_pc;
wire [31:0]  nextpc;

//------------------------------state control signal---------------------------------------
assign if_ready_go      = 1'b1;
assign if_allowin       = ~if_valid | if_ready_go & id_allowin;     
assign if_to_id_valid   = if_valid & if_ready_go;
always @(posedge clk) begin
    if_valid <= resetn; // 在reset撤销的下一个时钟上升沿才开始取指
end


//------------------------------inst sram interface---------------------------------------    
assign inst_sram_en     = if_allowin & resetn;
assign inst_sram_we     = 4'b0;
assign inst_sram_addr   = nextpc;
assign inst_sram_wdata  = 32'b0;


//------------------------------pc relavant signals---------------------------------------    
assign seq_pc           = if_pc + 3'h4;  
assign nextpc           = br_taken ? br_target : seq_pc;


//------------------------------if and id state interface---------------------------------------
always @(posedge clk) begin
    if(~resetn)
        if_pc <= 32'h1BFF_FFFC;
    else if(if_allowin)
        if_pc <= nextpc;
end
assign if_inst          = inst_sram_rdata;


endmodule
