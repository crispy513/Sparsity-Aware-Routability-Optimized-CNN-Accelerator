/////////////////////////////////////////////////////////////
// Created by: Synopsys DC Expert(TM) in wire load mode
// Version   : W-2024.09-SP2
// Date      : Sat May 30 19:04:31 2026
/////////////////////////////////////////////////////////////


module GIN ( clk, rst, GIN_valid, GIN_ready, GIN_data, tag_X, tag_Y, set_XID, 
        XID_scan_in, set_YID, YID_scan_in, PE_ready, PE_valid, PE_data );
  input [31:0] GIN_data;
  input [5:0] tag_X;
  input [2:0] tag_Y;
  input [5:0] XID_scan_in;
  input [2:0] YID_scan_in;
  input [47:0] PE_ready;
  output [47:0] PE_valid;
  output [1535:0] PE_data;
  input clk, rst, GIN_valid, set_XID, set_YID;
  output GIN_ready;
  wire   n1, n2, n3, n4, n5, n6, n7, n8, n9, n10, n11, n12, n13, n14, n15;
  tri   clk;
  tri   rst;
  tri   GIN_valid;
  tri   GIN_ready;
  tri   [31:0] GIN_data;
  tri   [2:0] tag_Y;
  tri   set_XID;
  tri   [5:0] XID_scan_in;
  tri   set_YID;
  tri   [2:0] YID_scan_in;
  tri   [47:0] PE_ready;
  tri   [47:0] PE_valid;
  tri   [1535:0] PE_data;
  tri   [5:0] GIN_XTAG_PIPELINE_XBus_tag_X_reg;
  tri   scan_chain_5__5_;
  tri   scan_chain_5__4_;
  tri   scan_chain_5__3_;
  tri   scan_chain_5__2_;
  tri   scan_chain_5__1_;
  tri   scan_chain_5__0_;
  tri   scan_chain_4__5_;
  tri   scan_chain_4__4_;
  tri   scan_chain_4__3_;
  tri   scan_chain_4__2_;
  tri   scan_chain_4__1_;
  tri   scan_chain_4__0_;
  tri   scan_chain_3__5_;
  tri   scan_chain_3__4_;
  tri   scan_chain_3__3_;
  tri   scan_chain_3__2_;
  tri   scan_chain_3__1_;
  tri   scan_chain_3__0_;
  tri   scan_chain_2__5_;
  tri   scan_chain_2__4_;
  tri   scan_chain_2__3_;
  tri   scan_chain_2__2_;
  tri   scan_chain_2__1_;
  tri   scan_chain_2__0_;
  tri   scan_chain_1__5_;
  tri   scan_chain_1__4_;
  tri   scan_chain_1__3_;
  tri   scan_chain_1__2_;
  tri   scan_chain_1__1_;
  tri   scan_chain_1__0_;
  tri   \XBus_valid[5] ;
  tri   \XBus_valid[4] ;
  tri   \XBus_valid[3] ;
  tri   \XBus_valid[2] ;
  tri   \XBus_valid[1] ;
  tri   \XBus_valid[0] ;
  tri   \XBus_ready[5] ;
  tri   \XBus_ready[4] ;
  tri   \XBus_ready[3] ;
  tri   \XBus_ready[2] ;
  tri   \XBus_ready[1] ;
  tri   \XBus_ready[0] ;
  tri   \XBus_data[9] ;
  tri   \XBus_data[99] ;
  tri   \XBus_data[98] ;
  tri   \XBus_data[97] ;
  tri   \XBus_data[96] ;
  tri   \XBus_data[95] ;
  tri   \XBus_data[94] ;
  tri   \XBus_data[93] ;
  tri   \XBus_data[92] ;
  tri   \XBus_data[91] ;
  tri   \XBus_data[90] ;
  tri   \XBus_data[8] ;
  tri   \XBus_data[89] ;
  tri   \XBus_data[88] ;
  tri   \XBus_data[87] ;
  tri   \XBus_data[86] ;
  tri   \XBus_data[85] ;
  tri   \XBus_data[84] ;
  tri   \XBus_data[83] ;
  tri   \XBus_data[82] ;
  tri   \XBus_data[81] ;
  tri   \XBus_data[80] ;
  tri   \XBus_data[7] ;
  tri   \XBus_data[79] ;
  tri   \XBus_data[78] ;
  tri   \XBus_data[77] ;
  tri   \XBus_data[76] ;
  tri   \XBus_data[75] ;
  tri   \XBus_data[74] ;
  tri   \XBus_data[73] ;
  tri   \XBus_data[72] ;
  tri   \XBus_data[71] ;
  tri   \XBus_data[70] ;
  tri   \XBus_data[6] ;
  tri   \XBus_data[69] ;
  tri   \XBus_data[68] ;
  tri   \XBus_data[67] ;
  tri   \XBus_data[66] ;
  tri   \XBus_data[65] ;
  tri   \XBus_data[64] ;
  tri   \XBus_data[63] ;
  tri   \XBus_data[62] ;
  tri   \XBus_data[61] ;
  tri   \XBus_data[60] ;
  tri   \XBus_data[5] ;
  tri   \XBus_data[59] ;
  tri   \XBus_data[58] ;
  tri   \XBus_data[57] ;
  tri   \XBus_data[56] ;
  tri   \XBus_data[55] ;
  tri   \XBus_data[54] ;
  tri   \XBus_data[53] ;
  tri   \XBus_data[52] ;
  tri   \XBus_data[51] ;
  tri   \XBus_data[50] ;
  tri   \XBus_data[4] ;
  tri   \XBus_data[49] ;
  tri   \XBus_data[48] ;
  tri   \XBus_data[47] ;
  tri   \XBus_data[46] ;
  tri   \XBus_data[45] ;
  tri   \XBus_data[44] ;
  tri   \XBus_data[43] ;
  tri   \XBus_data[42] ;
  tri   \XBus_data[41] ;
  tri   \XBus_data[40] ;
  tri   \XBus_data[3] ;
  tri   \XBus_data[39] ;
  tri   \XBus_data[38] ;
  tri   \XBus_data[37] ;
  tri   \XBus_data[36] ;
  tri   \XBus_data[35] ;
  tri   \XBus_data[34] ;
  tri   \XBus_data[33] ;
  tri   \XBus_data[32] ;
  tri   \XBus_data[31] ;
  tri   \XBus_data[30] ;
  tri   \XBus_data[2] ;
  tri   \XBus_data[29] ;
  tri   \XBus_data[28] ;
  tri   \XBus_data[27] ;
  tri   \XBus_data[26] ;
  tri   \XBus_data[25] ;
  tri   \XBus_data[24] ;
  tri   \XBus_data[23] ;
  tri   \XBus_data[22] ;
  tri   \XBus_data[21] ;
  tri   \XBus_data[20] ;
  tri   \XBus_data[1] ;
  tri   \XBus_data[19] ;
  tri   \XBus_data[191] ;
  tri   \XBus_data[190] ;
  tri   \XBus_data[18] ;
  tri   \XBus_data[189] ;
  tri   \XBus_data[188] ;
  tri   \XBus_data[187] ;
  tri   \XBus_data[186] ;
  tri   \XBus_data[185] ;
  tri   \XBus_data[184] ;
  tri   \XBus_data[183] ;
  tri   \XBus_data[182] ;
  tri   \XBus_data[181] ;
  tri   \XBus_data[180] ;
  tri   \XBus_data[17] ;
  tri   \XBus_data[179] ;
  tri   \XBus_data[178] ;
  tri   \XBus_data[177] ;
  tri   \XBus_data[176] ;
  tri   \XBus_data[175] ;
  tri   \XBus_data[174] ;
  tri   \XBus_data[173] ;
  tri   \XBus_data[172] ;
  tri   \XBus_data[171] ;
  tri   \XBus_data[170] ;
  tri   \XBus_data[16] ;
  tri   \XBus_data[169] ;
  tri   \XBus_data[168] ;
  tri   \XBus_data[167] ;
  tri   \XBus_data[166] ;
  tri   \XBus_data[165] ;
  tri   \XBus_data[164] ;
  tri   \XBus_data[163] ;
  tri   \XBus_data[162] ;
  tri   \XBus_data[161] ;
  tri   \XBus_data[160] ;
  tri   \XBus_data[15] ;
  tri   \XBus_data[159] ;
  tri   \XBus_data[158] ;
  tri   \XBus_data[157] ;
  tri   \XBus_data[156] ;
  tri   \XBus_data[155] ;
  tri   \XBus_data[154] ;
  tri   \XBus_data[153] ;
  tri   \XBus_data[152] ;
  tri   \XBus_data[151] ;
  tri   \XBus_data[150] ;
  tri   \XBus_data[14] ;
  tri   \XBus_data[149] ;
  tri   \XBus_data[148] ;
  tri   \XBus_data[147] ;
  tri   \XBus_data[146] ;
  tri   \XBus_data[145] ;
  tri   \XBus_data[144] ;
  tri   \XBus_data[143] ;
  tri   \XBus_data[142] ;
  tri   \XBus_data[141] ;
  tri   \XBus_data[140] ;
  tri   \XBus_data[13] ;
  tri   \XBus_data[139] ;
  tri   \XBus_data[138] ;
  tri   \XBus_data[137] ;
  tri   \XBus_data[136] ;
  tri   \XBus_data[135] ;
  tri   \XBus_data[134] ;
  tri   \XBus_data[133] ;
  tri   \XBus_data[132] ;
  tri   \XBus_data[131] ;
  tri   \XBus_data[130] ;
  tri   \XBus_data[12] ;
  tri   \XBus_data[129] ;
  tri   \XBus_data[128] ;
  tri   \XBus_data[127] ;
  tri   \XBus_data[126] ;
  tri   \XBus_data[125] ;
  tri   \XBus_data[124] ;
  tri   \XBus_data[123] ;
  tri   \XBus_data[122] ;
  tri   \XBus_data[121] ;
  tri   \XBus_data[120] ;
  tri   \XBus_data[11] ;
  tri   \XBus_data[119] ;
  tri   \XBus_data[118] ;
  tri   \XBus_data[117] ;
  tri   \XBus_data[116] ;
  tri   \XBus_data[115] ;
  tri   \XBus_data[114] ;
  tri   \XBus_data[113] ;
  tri   \XBus_data[112] ;
  tri   \XBus_data[111] ;
  tri   \XBus_data[110] ;
  tri   \XBus_data[10] ;
  tri   \XBus_data[109] ;
  tri   \XBus_data[108] ;
  tri   \XBus_data[107] ;
  tri   \XBus_data[106] ;
  tri   \XBus_data[105] ;
  tri   \XBus_data[104] ;
  tri   \XBus_data[103] ;
  tri   \XBus_data[102] ;
  tri   \XBus_data[101] ;
  tri   \XBus_data[100] ;
  tri   \XBus_data[0] ;

  DFQD2BWP16P90LVT GIN_XTAG_PIPELINE_XBus_tag_X_reg_reg_0_ ( .D(n15), .CP(clk), 
        .Q(GIN_XTAG_PIPELINE_XBus_tag_X_reg[0]) );
  DFQD2BWP16P90LVT GIN_XTAG_PIPELINE_XBus_tag_X_reg_reg_1_ ( .D(n14), .CP(clk), 
        .Q(GIN_XTAG_PIPELINE_XBus_tag_X_reg[1]) );
  DFQD2BWP16P90LVT GIN_XTAG_PIPELINE_XBus_tag_X_reg_reg_2_ ( .D(n13), .CP(clk), 
        .Q(GIN_XTAG_PIPELINE_XBus_tag_X_reg[2]) );
  DFQD2BWP16P90LVT GIN_XTAG_PIPELINE_XBus_tag_X_reg_reg_3_ ( .D(n12), .CP(clk), 
        .Q(GIN_XTAG_PIPELINE_XBus_tag_X_reg[3]) );
  DFQD2BWP16P90LVT GIN_XTAG_PIPELINE_XBus_tag_X_reg_reg_4_ ( .D(n11), .CP(clk), 
        .Q(GIN_XTAG_PIPELINE_XBus_tag_X_reg[4]) );
  DFQD2BWP16P90LVT GIN_XTAG_PIPELINE_XBus_tag_X_reg_reg_5_ ( .D(n10), .CP(clk), 
        .Q(GIN_XTAG_PIPELINE_XBus_tag_X_reg[5]) );
  NR2D1BWP16P90 U9 ( .A1(n3), .A2(rst), .ZN(n2) );
  INR2D1BWP16P90 U10 ( .A1(n3), .B1(rst), .ZN(n1) );
  ND2D1BWP16P90 U11 ( .A1(GIN_valid), .A2(GIN_ready), .ZN(n3) );
  DEL050D1BWP20P90 U12 ( .I(n4), .Z(n10) );
  AO22D4BWP20P90 U13 ( .A1(GIN_XTAG_PIPELINE_XBus_tag_X_reg[5]), .A2(n1), .B1(
        tag_X[5]), .B2(n2), .Z(n4) );
  DEL075D1BWP20P90 U14 ( .I(n5), .Z(n11) );
  AO22D2BWP20P90LVT U15 ( .A1(GIN_XTAG_PIPELINE_XBus_tag_X_reg[4]), .A2(n1), 
        .B1(tag_X[4]), .B2(n2), .Z(n5) );
  DEL075D1BWP20P90 U16 ( .I(n6), .Z(n12) );
  AO22D2BWP20P90LVT U17 ( .A1(GIN_XTAG_PIPELINE_XBus_tag_X_reg[3]), .A2(n1), 
        .B1(tag_X[3]), .B2(n2), .Z(n6) );
  DEL075D1BWP20P90 U18 ( .I(n7), .Z(n13) );
  AO22D2BWP20P90LVT U19 ( .A1(GIN_XTAG_PIPELINE_XBus_tag_X_reg[2]), .A2(n1), 
        .B1(tag_X[2]), .B2(n2), .Z(n7) );
  DEL075D1BWP20P90 U20 ( .I(n8), .Z(n14) );
  AO22D2BWP20P90LVT U21 ( .A1(GIN_XTAG_PIPELINE_XBus_tag_X_reg[1]), .A2(n1), 
        .B1(tag_X[1]), .B2(n2), .Z(n8) );
  DEL075D1BWP20P90 U22 ( .I(n9), .Z(n15) );
  AO22D2BWP20P90LVT U23 ( .A1(GIN_XTAG_PIPELINE_XBus_tag_X_reg[0]), .A2(n1), 
        .B1(tag_X[0]), .B2(n2), .Z(n9) );
  GIN_Bus YBus ( .clk(clk), .rst(rst), .tag(tag_Y), .master_valid(GIN_valid), 
        .master_data(GIN_data), .master_ready(GIN_ready), .slave_ready({
        \XBus_ready[5] , \XBus_ready[4] , \XBus_ready[3] , \XBus_ready[2] , 
        \XBus_ready[1] , \XBus_ready[0] }), .slave_valid({\XBus_valid[5] , 
        \XBus_valid[4] , \XBus_valid[3] , \XBus_valid[2] , \XBus_valid[1] , 
        \XBus_valid[0] }), .slave_data({\XBus_data[191] , \XBus_data[190] , 
        \XBus_data[189] , \XBus_data[188] , \XBus_data[187] , \XBus_data[186] , 
        \XBus_data[185] , \XBus_data[184] , \XBus_data[183] , \XBus_data[182] , 
        \XBus_data[181] , \XBus_data[180] , \XBus_data[179] , \XBus_data[178] , 
        \XBus_data[177] , \XBus_data[176] , \XBus_data[175] , \XBus_data[174] , 
        \XBus_data[173] , \XBus_data[172] , \XBus_data[171] , \XBus_data[170] , 
        \XBus_data[169] , \XBus_data[168] , \XBus_data[167] , \XBus_data[166] , 
        \XBus_data[165] , \XBus_data[164] , \XBus_data[163] , \XBus_data[162] , 
        \XBus_data[161] , \XBus_data[160] , \XBus_data[159] , \XBus_data[158] , 
        \XBus_data[157] , \XBus_data[156] , \XBus_data[155] , \XBus_data[154] , 
        \XBus_data[153] , \XBus_data[152] , \XBus_data[151] , \XBus_data[150] , 
        \XBus_data[149] , \XBus_data[148] , \XBus_data[147] , \XBus_data[146] , 
        \XBus_data[145] , \XBus_data[144] , \XBus_data[143] , \XBus_data[142] , 
        \XBus_data[141] , \XBus_data[140] , \XBus_data[139] , \XBus_data[138] , 
        \XBus_data[137] , \XBus_data[136] , \XBus_data[135] , \XBus_data[134] , 
        \XBus_data[133] , \XBus_data[132] , \XBus_data[131] , \XBus_data[130] , 
        \XBus_data[129] , \XBus_data[128] , \XBus_data[127] , \XBus_data[126] , 
        \XBus_data[125] , \XBus_data[124] , \XBus_data[123] , \XBus_data[122] , 
        \XBus_data[121] , \XBus_data[120] , \XBus_data[119] , \XBus_data[118] , 
        \XBus_data[117] , \XBus_data[116] , \XBus_data[115] , \XBus_data[114] , 
        \XBus_data[113] , \XBus_data[112] , \XBus_data[111] , \XBus_data[110] , 
        \XBus_data[109] , \XBus_data[108] , \XBus_data[107] , \XBus_data[106] , 
        \XBus_data[105] , \XBus_data[104] , \XBus_data[103] , \XBus_data[102] , 
        \XBus_data[101] , \XBus_data[100] , \XBus_data[99] , \XBus_data[98] , 
        \XBus_data[97] , \XBus_data[96] , \XBus_data[95] , \XBus_data[94] , 
        \XBus_data[93] , \XBus_data[92] , \XBus_data[91] , \XBus_data[90] , 
        \XBus_data[89] , \XBus_data[88] , \XBus_data[87] , \XBus_data[86] , 
        \XBus_data[85] , \XBus_data[84] , \XBus_data[83] , \XBus_data[82] , 
        \XBus_data[81] , \XBus_data[80] , \XBus_data[79] , \XBus_data[78] , 
        \XBus_data[77] , \XBus_data[76] , \XBus_data[75] , \XBus_data[74] , 
        \XBus_data[73] , \XBus_data[72] , \XBus_data[71] , \XBus_data[70] , 
        \XBus_data[69] , \XBus_data[68] , \XBus_data[67] , \XBus_data[66] , 
        \XBus_data[65] , \XBus_data[64] , \XBus_data[63] , \XBus_data[62] , 
        \XBus_data[61] , \XBus_data[60] , \XBus_data[59] , \XBus_data[58] , 
        \XBus_data[57] , \XBus_data[56] , \XBus_data[55] , \XBus_data[54] , 
        \XBus_data[53] , \XBus_data[52] , \XBus_data[51] , \XBus_data[50] , 
        \XBus_data[49] , \XBus_data[48] , \XBus_data[47] , \XBus_data[46] , 
        \XBus_data[45] , \XBus_data[44] , \XBus_data[43] , \XBus_data[42] , 
        \XBus_data[41] , \XBus_data[40] , \XBus_data[39] , \XBus_data[38] , 
        \XBus_data[37] , \XBus_data[36] , \XBus_data[35] , \XBus_data[34] , 
        \XBus_data[33] , \XBus_data[32] , \XBus_data[31] , \XBus_data[30] , 
        \XBus_data[29] , \XBus_data[28] , \XBus_data[27] , \XBus_data[26] , 
        \XBus_data[25] , \XBus_data[24] , \XBus_data[23] , \XBus_data[22] , 
        \XBus_data[21] , \XBus_data[20] , \XBus_data[19] , \XBus_data[18] , 
        \XBus_data[17] , \XBus_data[16] , \XBus_data[15] , \XBus_data[14] , 
        \XBus_data[13] , \XBus_data[12] , \XBus_data[11] , \XBus_data[10] , 
        \XBus_data[9] , \XBus_data[8] , \XBus_data[7] , \XBus_data[6] , 
        \XBus_data[5] , \XBus_data[4] , \XBus_data[3] , \XBus_data[2] , 
        \XBus_data[1] , \XBus_data[0] }), .set_id(set_YID), .ID_scan_in(
        YID_scan_in) );
  GIN_Bus GIN_XBUS_0__XBus ( .clk(clk), .rst(rst), .tag(
        GIN_XTAG_PIPELINE_XBus_tag_X_reg), .master_valid(\XBus_valid[0] ), 
        .master_data({\XBus_data[31] , \XBus_data[30] , \XBus_data[29] , 
        \XBus_data[28] , \XBus_data[27] , \XBus_data[26] , \XBus_data[25] , 
        \XBus_data[24] , \XBus_data[23] , \XBus_data[22] , \XBus_data[21] , 
        \XBus_data[20] , \XBus_data[19] , \XBus_data[18] , \XBus_data[17] , 
        \XBus_data[16] , \XBus_data[15] , \XBus_data[14] , \XBus_data[13] , 
        \XBus_data[12] , \XBus_data[11] , \XBus_data[10] , \XBus_data[9] , 
        \XBus_data[8] , \XBus_data[7] , \XBus_data[6] , \XBus_data[5] , 
        \XBus_data[4] , \XBus_data[3] , \XBus_data[2] , \XBus_data[1] , 
        \XBus_data[0] }), .master_ready(\XBus_ready[0] ), .slave_ready(
        PE_ready[7:0]), .slave_valid(PE_valid[7:0]), .slave_data(
        PE_data[255:0]), .set_id(set_XID), .ID_scan_in({scan_chain_1__5_, 
        scan_chain_1__4_, scan_chain_1__3_, scan_chain_1__2_, scan_chain_1__1_, 
        scan_chain_1__0_}) );
  GIN_Bus GIN_XBUS_1__XBus ( .clk(clk), .rst(rst), .tag(
        GIN_XTAG_PIPELINE_XBus_tag_X_reg), .master_valid(\XBus_valid[1] ), 
        .master_data({\XBus_data[63] , \XBus_data[62] , \XBus_data[61] , 
        \XBus_data[60] , \XBus_data[59] , \XBus_data[58] , \XBus_data[57] , 
        \XBus_data[56] , \XBus_data[55] , \XBus_data[54] , \XBus_data[53] , 
        \XBus_data[52] , \XBus_data[51] , \XBus_data[50] , \XBus_data[49] , 
        \XBus_data[48] , \XBus_data[47] , \XBus_data[46] , \XBus_data[45] , 
        \XBus_data[44] , \XBus_data[43] , \XBus_data[42] , \XBus_data[41] , 
        \XBus_data[40] , \XBus_data[39] , \XBus_data[38] , \XBus_data[37] , 
        \XBus_data[36] , \XBus_data[35] , \XBus_data[34] , \XBus_data[33] , 
        \XBus_data[32] }), .master_ready(\XBus_ready[1] ), .slave_ready(
        PE_ready[15:8]), .slave_valid(PE_valid[15:8]), .slave_data(
        PE_data[511:256]), .set_id(set_XID), .ID_scan_in({scan_chain_2__5_, 
        scan_chain_2__4_, scan_chain_2__3_, scan_chain_2__2_, scan_chain_2__1_, 
        scan_chain_2__0_}), .ID_scan_out({scan_chain_1__5_, scan_chain_1__4_, 
        scan_chain_1__3_, scan_chain_1__2_, scan_chain_1__1_, scan_chain_1__0_}) );
  GIN_Bus GIN_XBUS_2__XBus ( .clk(clk), .rst(rst), .tag(
        GIN_XTAG_PIPELINE_XBus_tag_X_reg), .master_valid(\XBus_valid[2] ), 
        .master_data({\XBus_data[95] , \XBus_data[94] , \XBus_data[93] , 
        \XBus_data[92] , \XBus_data[91] , \XBus_data[90] , \XBus_data[89] , 
        \XBus_data[88] , \XBus_data[87] , \XBus_data[86] , \XBus_data[85] , 
        \XBus_data[84] , \XBus_data[83] , \XBus_data[82] , \XBus_data[81] , 
        \XBus_data[80] , \XBus_data[79] , \XBus_data[78] , \XBus_data[77] , 
        \XBus_data[76] , \XBus_data[75] , \XBus_data[74] , \XBus_data[73] , 
        \XBus_data[72] , \XBus_data[71] , \XBus_data[70] , \XBus_data[69] , 
        \XBus_data[68] , \XBus_data[67] , \XBus_data[66] , \XBus_data[65] , 
        \XBus_data[64] }), .master_ready(\XBus_ready[2] ), .slave_ready(
        PE_ready[23:16]), .slave_valid(PE_valid[23:16]), .slave_data(
        PE_data[767:512]), .set_id(set_XID), .ID_scan_in({scan_chain_3__5_, 
        scan_chain_3__4_, scan_chain_3__3_, scan_chain_3__2_, scan_chain_3__1_, 
        scan_chain_3__0_}), .ID_scan_out({scan_chain_2__5_, scan_chain_2__4_, 
        scan_chain_2__3_, scan_chain_2__2_, scan_chain_2__1_, scan_chain_2__0_}) );
  GIN_Bus GIN_XBUS_3__XBus ( .clk(clk), .rst(rst), .tag(
        GIN_XTAG_PIPELINE_XBus_tag_X_reg), .master_valid(\XBus_valid[3] ), 
        .master_data({\XBus_data[127] , \XBus_data[126] , \XBus_data[125] , 
        \XBus_data[124] , \XBus_data[123] , \XBus_data[122] , \XBus_data[121] , 
        \XBus_data[120] , \XBus_data[119] , \XBus_data[118] , \XBus_data[117] , 
        \XBus_data[116] , \XBus_data[115] , \XBus_data[114] , \XBus_data[113] , 
        \XBus_data[112] , \XBus_data[111] , \XBus_data[110] , \XBus_data[109] , 
        \XBus_data[108] , \XBus_data[107] , \XBus_data[106] , \XBus_data[105] , 
        \XBus_data[104] , \XBus_data[103] , \XBus_data[102] , \XBus_data[101] , 
        \XBus_data[100] , \XBus_data[99] , \XBus_data[98] , \XBus_data[97] , 
        \XBus_data[96] }), .master_ready(\XBus_ready[3] ), .slave_ready(
        PE_ready[31:24]), .slave_valid(PE_valid[31:24]), .slave_data(
        PE_data[1023:768]), .set_id(set_XID), .ID_scan_in({scan_chain_4__5_, 
        scan_chain_4__4_, scan_chain_4__3_, scan_chain_4__2_, scan_chain_4__1_, 
        scan_chain_4__0_}), .ID_scan_out({scan_chain_3__5_, scan_chain_3__4_, 
        scan_chain_3__3_, scan_chain_3__2_, scan_chain_3__1_, scan_chain_3__0_}) );
  GIN_Bus GIN_XBUS_4__XBus ( .clk(clk), .rst(rst), .tag(
        GIN_XTAG_PIPELINE_XBus_tag_X_reg), .master_valid(\XBus_valid[4] ), 
        .master_data({\XBus_data[159] , \XBus_data[158] , \XBus_data[157] , 
        \XBus_data[156] , \XBus_data[155] , \XBus_data[154] , \XBus_data[153] , 
        \XBus_data[152] , \XBus_data[151] , \XBus_data[150] , \XBus_data[149] , 
        \XBus_data[148] , \XBus_data[147] , \XBus_data[146] , \XBus_data[145] , 
        \XBus_data[144] , \XBus_data[143] , \XBus_data[142] , \XBus_data[141] , 
        \XBus_data[140] , \XBus_data[139] , \XBus_data[138] , \XBus_data[137] , 
        \XBus_data[136] , \XBus_data[135] , \XBus_data[134] , \XBus_data[133] , 
        \XBus_data[132] , \XBus_data[131] , \XBus_data[130] , \XBus_data[129] , 
        \XBus_data[128] }), .master_ready(\XBus_ready[4] ), .slave_ready(
        PE_ready[39:32]), .slave_valid(PE_valid[39:32]), .slave_data(
        PE_data[1279:1024]), .set_id(set_XID), .ID_scan_in({scan_chain_5__5_, 
        scan_chain_5__4_, scan_chain_5__3_, scan_chain_5__2_, scan_chain_5__1_, 
        scan_chain_5__0_}), .ID_scan_out({scan_chain_4__5_, scan_chain_4__4_, 
        scan_chain_4__3_, scan_chain_4__2_, scan_chain_4__1_, scan_chain_4__0_}) );
  GIN_Bus GIN_XBUS_5__XBus ( .clk(clk), .rst(rst), .tag(
        GIN_XTAG_PIPELINE_XBus_tag_X_reg), .master_valid(\XBus_valid[5] ), 
        .master_data({\XBus_data[191] , \XBus_data[190] , \XBus_data[189] , 
        \XBus_data[188] , \XBus_data[187] , \XBus_data[186] , \XBus_data[185] , 
        \XBus_data[184] , \XBus_data[183] , \XBus_data[182] , \XBus_data[181] , 
        \XBus_data[180] , \XBus_data[179] , \XBus_data[178] , \XBus_data[177] , 
        \XBus_data[176] , \XBus_data[175] , \XBus_data[174] , \XBus_data[173] , 
        \XBus_data[172] , \XBus_data[171] , \XBus_data[170] , \XBus_data[169] , 
        \XBus_data[168] , \XBus_data[167] , \XBus_data[166] , \XBus_data[165] , 
        \XBus_data[164] , \XBus_data[163] , \XBus_data[162] , \XBus_data[161] , 
        \XBus_data[160] }), .master_ready(\XBus_ready[5] ), .slave_ready(
        PE_ready[47:40]), .slave_valid(PE_valid[47:40]), .slave_data(
        PE_data[1535:1280]), .set_id(set_XID), .ID_scan_in(XID_scan_in), 
        .ID_scan_out({scan_chain_5__5_, scan_chain_5__4_, scan_chain_5__3_, 
        scan_chain_5__2_, scan_chain_5__1_, scan_chain_5__0_}) );
endmodule

