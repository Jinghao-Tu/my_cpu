module adder (
    output wire [63:0] C,
    output wire [63:0] S,
    input  wire [63:0] in1,
    input  wire [63:0] in2,
    input  wire [63:0] in3
);
assign S = in1^in2^in3;
assign C = {(in1 & in2 | in2 & in3 | in3 & in1), 1'b0};
endmodule

module mul (
    input  wire         clk,
    input  wire         resetn,
    input  wire         mul_en,
    input  wire         mul_signed,
    input  wire [31:0]  A,
    input  wire [31:0]  B,
    output wire [63:0]  result,
    output wire         complete
);
// 采用 booth 算法和 wallace 树
wire [63:0] A_add;
wire [63:0] A_sub;
wire [63:0] A2_add;
wire [63:0] A2_sub;
wire [33:0] sel_0;
wire [33:0] sel_x;
wire [33:0] sel_2x;
wire [33:0] sel_mx;     // m --- minus
wire [33:0] sel_m2x;
wire [16:0] sel_0_val;
wire [16:0] sel_x_val;
wire [16:0] sel_2x_val;
wire [16:0] sel_mx_val;
wire [16:0] sel_m2x_val;

wire [33:0] B_m;    // 进行双符号位拓展
wire [33:0] B_h;    // 高 33 位
wire [33:0] B_l;    // 低 33 位

wire [63:0] PP[16:0];

reg         counter;
always @(posedge clk) begin
    if (~resetn) begin
        counter <= 1'b0;
    end else if (mul_en & ~counter) begin
        counter <= 1'b1;
    end else begin
        counter <= 1'b0;
    end
end
assign complete = mul_en & counter;

assign B_m = {{2{B[31] & mul_signed}}, B};
assign B_h = {1'b0, B_m[33:1]};
assign B_l = {B_m[32:0], 1'b0};

assign sel_0        = (~B_h & ~B_m & ~B_l) | ( B_h &  B_m &  B_l);  // 000, 111
assign sel_x        = (~B_h & ~B_m &  B_l) | (~B_h &  B_m & ~B_l);  // 001, 010
assign sel_2x       = (~B_h &  B_m &  B_l);                         // 011
assign sel_mx       = ( B_h & ~B_m &  B_l) | ( B_h &  B_m & ~B_l);  // 101, 110
assign sel_m2x      = ( B_h & ~B_m & ~B_l);                         // 100
assign A_add        = {{32{A[31] & mul_signed}}, A};
assign A_sub        = ~A_add + 1'b1;
assign A2_add       = {A_add, 1'b0};
assign A2_sub       = ~A2_add + 1'b1;

assign sel_0_val    = { sel_0[32], sel_0[30], sel_0[28], sel_0[26], sel_0[24],
                        sel_0[22], sel_0[20], sel_0[18], sel_0[16],
                        sel_0[14], sel_0[12], sel_0[10], sel_0[ 8],
                        sel_0[ 6], sel_0[ 4], sel_0[ 2], sel_0[ 0]};
assign sel_x_val    = { sel_x[32], sel_x[30], sel_x[28], sel_x[26], sel_x[24],
                        sel_x[22], sel_x[20], sel_x[18], sel_x[16],
                        sel_x[14], sel_x[12], sel_x[10], sel_x[ 8],
                        sel_x[ 6], sel_x[ 4], sel_x[ 2], sel_x[ 0]};
assign sel_mx_val   = { sel_mx[32], sel_mx[30], sel_mx[28], sel_mx[26], sel_mx[24],
                        sel_mx[22], sel_mx[20], sel_mx[18], sel_mx[16],
                        sel_mx[14], sel_mx[12], sel_mx[10], sel_mx[ 8],
                        sel_mx[ 6], sel_mx[ 4], sel_mx[ 2], sel_mx[ 0]};     
assign sel_2x_val   = { sel_2x[32], sel_2x[30], sel_2x[28], sel_2x[26], sel_2x[24],
                        sel_2x[22], sel_2x[20], sel_2x[18], sel_2x[16],
                        sel_2x[14], sel_2x[12], sel_2x[10], sel_2x[ 8],
                        sel_2x[ 6], sel_2x[ 4], sel_2x[ 2], sel_2x[ 0]};        
assign sel_m2x_val  = { sel_m2x[32], sel_m2x[30], sel_m2x[28], sel_m2x[26], sel_m2x[24],
                        sel_m2x[22], sel_m2x[20], sel_m2x[18], sel_m2x[16],
                        sel_m2x[14], sel_m2x[12], sel_m2x[10], sel_m2x[ 8],
                        sel_m2x[ 6], sel_m2x[ 4], sel_m2x[ 2], sel_m2x[ 0]};

assign {PP[16], PP[15], PP[14], PP[13], PP[12],
        PP[11], PP[10], PP[ 9], PP[ 8],
        PP[ 7], PP[ 6], PP[ 5], PP[ 4],
        PP[ 3], PP[ 2], PP[ 1], PP[ 0]} 
        =  {{64{sel_x_val[16]}},    {64{sel_x_val[15]}},    {64{sel_x_val[14]}},    {64{sel_x_val[13]}},    {64{sel_x_val[12]}},
            {64{sel_x_val[11]}},    {64{sel_x_val[10]}},    {64{sel_x_val[ 9]}},    {64{sel_x_val[ 8]}},
            {64{sel_x_val[ 7]}},    {64{sel_x_val[ 6]}},    {64{sel_x_val[ 5]}},    {64{sel_x_val[ 4]}},
            {64{sel_x_val[ 3]}},    {64{sel_x_val[ 2]}},    {64{sel_x_val[ 1]}},    {64{sel_x_val[ 0]}}}&   {17{A_add}} |
            {{64{sel_mx_val[16]}},   {64{sel_mx_val[15]}},   {64{sel_mx_val[14]}},   {64{sel_mx_val[13]}},   {64{sel_mx_val[12]}},
            {64{sel_mx_val[11]}},   {64{sel_mx_val[10]}},   {64{sel_mx_val[ 9]}},   {64{sel_mx_val[ 8]}},
            {64{sel_mx_val[ 7]}},   {64{sel_mx_val[ 6]}},   {64{sel_mx_val[ 5]}},   {64{sel_mx_val[ 4]}},
            {64{sel_mx_val[ 3]}},   {64{sel_mx_val[ 2]}},   {64{sel_mx_val[ 1]}},   {64{sel_mx_val[ 0]}}}&  {17{A_sub}} |
            {{64{sel_2x_val[16]}},   {64{sel_2x_val[15]}},   {64{sel_2x_val[14]}},   {64{sel_2x_val[13]}},   {64{sel_2x_val[12]}},
            {64{sel_2x_val[11]}},   {64{sel_2x_val[10]}},   {64{sel_2x_val[ 9]}},   {64{sel_2x_val[ 8]}},
            {64{sel_2x_val[ 7]}},   {64{sel_2x_val[ 6]}},   {64{sel_2x_val[ 5]}},   {64{sel_2x_val[ 4]}},
            {64{sel_2x_val[ 3]}},   {64{sel_2x_val[ 2]}},   {64{sel_2x_val[ 1]}},   {64{sel_2x_val[ 0]}}}&  {17{A2_add}} |
            {{64{sel_m2x_val[16]}},  {64{sel_m2x_val[15]}},  {64{sel_m2x_val[14]}},  {64{sel_m2x_val[13]}},  {64{sel_m2x_val[12]}},
            {64{sel_m2x_val[11]}},  {64{sel_m2x_val[10]}},  {64{sel_m2x_val[ 9]}},  {64{sel_m2x_val[ 8]}},
            {64{sel_m2x_val[ 7]}},  {64{sel_m2x_val[ 6]}},  {64{sel_m2x_val[ 5]}},  {64{sel_m2x_val[ 4]}},
            {64{sel_m2x_val[ 3]}},  {64{sel_m2x_val[ 2]}},  {64{sel_m2x_val[ 1]}},  {64{sel_m2x_val[ 0]}}}& {17{A2_sub}}; 

//--------------------------level 1--------------------------
wire [63:0] level1 [11:0];
adder adder1_1 (
    .in1({PP[ 1][61:0],2'b0}),
    .in2({PP[ 2][59:0],  4'b0}),
    .in3({PP[ 3][57:0],  6'b0}),
    .C(level1[ 1]),
    .S(level1[ 2])
);
adder adder1_2 (
    .in1({PP[ 4][55:0],  8'b0}),
    .in2({PP[ 5][53:0], 10'b0}),
    .in3({PP[ 6][51:0], 12'b0}),
    .C(level1[ 3]),
    .S(level1[ 4])
);
adder adder1_3 (
    .in1({PP[ 7][49:0], 14'b0}),
    .in2({PP[ 8][47:0], 16'b0}),
    .in3({PP[ 9][45:0], 18'b0}),
    .C(level1[ 5]),
    .S(level1[ 6])
);
adder adder1_4 (
    .in1({PP[10][43:0], 20'b0}),
    .in2({PP[11][41:0], 22'b0}),
    .in3({PP[12][39:0], 24'b0}),
    .C(level1[ 7]),
    .S(level1[ 8])
);
adder adder1_5 (
    .in1({PP[13][37:0], 26'b0}),
    .in2({PP[14][35:0], 28'b0}),
    .in3({PP[15][33:0], 30'b0}),
    .C(level1[ 9]),
    .S(level1[10])
);
assign level1[ 0] = PP[0];
assign level1[11] = {PP[16][31:0], 32'b0};


//--------------------------level 2--------------------------
wire [63:0] level2 [7:0];
adder adder2_1 (
    .in1(level1[ 0]),
    .in2(level1[ 1]),
    .in3(level1[ 2]),
    .C(level2[0]),
    .S(level2[1])
);
adder adder2_2 (
    .in1(level1[ 3]),
    .in2(level1[ 4]),
    .in3(level1[ 5]),
    .C(level2[2]),
    .S(level2[3])
);
adder adder2_3 (
    .in1(level1[ 6]),
    .in2(level1[ 7]),
    .in3(level1[ 8]),
    .C(level2[4]),
    .S(level2[5])
);
adder adder2_4 (
    .in1(level1[ 9]),
    .in2(level1[10]),
    .in3(level1[11]),
    .C(level2[6]),
    .S(level2[7])
);


//--------------------------level 3--------------------------
wire [63:0] level3 [5:0];
adder adder3_1 (
    .in1(level2[0]),
    .in2(level2[1]),
    .in3(level2[2]),
    .C(level3[0]),
    .S(level3[1])
);
adder adder3_2 (
    .in1(level2[3]),
    .in2(level2[4]),
    .in3(level2[5]),
    .C(level3[2]),
    .S(level3[3])
);
assign level3[4] = level2[6];
assign level3[5] = level2[7];


//--------------------------level 4--------------------------
wire [63:0] level4 [3:0];
adder adder4_1 (
    .in1(level3[0]),
    .in2(level3[1]),
    .in3(level3[2]),
    .C(level4[0]),
    .S(level4[1])
);
adder adder4_2 (
    .in1(level3[3]),
    .in2(level3[4]),
    .in3(level3[5]),
    .C(level4[2]),
    .S(level4[3])
);


//--------------------------level 5--------------------------
wire [63:0] level5 [2:0];
adder adder5_1 (
    .in1(level4[0]),
    .in2(level4[1]),
    .in3(level4[2]),
    .C(level5[0]),
    .S(level5[1])
);
assign level5[2] = level4[3]; 


//--------------------------level 6--------------------------
wire [63:0] level6 [1:0];
adder adder6_1 (
    .in1(level5[0]),
    .in2(level5[1]),
    .in3(level5[2]),
    .C(level6[0]),
    .S(level6[1])
);


//--------------------------level 7--------------------------
assign result = (level6[0] + level6[1]) & {64{resetn}};


endmodule