`ifndef PE_ARRAY_SV
`define PE_ARRAY_SV

`include "define.svh"
`include "src/PE_array/GIN/GIN.sv"
`include "src/PE_array/PE_cluster.sv"
`include "src/PE_array/GON/GON.sv"

module PE_array #(
    parameter int NUMS_PE_ROW        = `NUMS_PE_ROW,
    parameter int NUMS_PE_COL        = `NUMS_PE_COL,
    parameter int XID_BITS           = `XID_BITS,
    parameter int YID_BITS           = `YID_BITS,
    parameter int DATA_SIZE          = `DATA_BITS,
    parameter int CONFIG_SIZE        = `CONFIG_SIZE,

    parameter int PE_ROW_PER_CLUSTER = 2,
    parameter int PE_COL_PER_CLUSTER = 2,
    parameter int NUMS_CLUSTER_ROW   = NUMS_PE_ROW / PE_ROW_PER_CLUSTER,
    parameter int NUMS_CLUSTER_COL   = NUMS_PE_COL / PE_COL_PER_CLUSTER
)(
    input  logic clk,
    input  logic rst,

    input  logic set_XID,
    input  logic [XID_BITS-1:0] ifmap_XID_scan_in,
    input  logic [XID_BITS-1:0] filter_XID_scan_in,
    input  logic [XID_BITS-1:0] ipsum_XID_scan_in,
    input  logic [XID_BITS-1:0] opsum_XID_scan_in,

    input  logic set_YID,
    input  logic [YID_BITS-1:0] ifmap_YID_scan_in,
    input  logic [YID_BITS-1:0] filter_YID_scan_in,
    input  logic [YID_BITS-1:0] ipsum_YID_scan_in,
    input  logic [YID_BITS-1:0] opsum_YID_scan_in,

    input  logic set_LN,
    input  logic [NUMS_PE_ROW-2:0] LN_config_in,

    input  logic [NUMS_PE_ROW*NUMS_PE_COL-1:0] PE_en,
    input  logic [CONFIG_SIZE-1:0] PE_config,
    input  logic [XID_BITS-1:0] ifmap_tag_X,
    input  logic [YID_BITS-1:0] ifmap_tag_Y,
    input  logic [XID_BITS-1:0] filter_tag_X,
    input  logic [YID_BITS-1:0] filter_tag_Y,
    input  logic [XID_BITS-1:0] ipsum_tag_X,
    input  logic [YID_BITS-1:0] ipsum_tag_Y,
    input  logic [XID_BITS-1:0] opsum_tag_X,
    input  logic [YID_BITS-1:0] opsum_tag_Y,

    input  logic                 GLB_ifmap_valid,
    output logic                 GLB_ifmap_ready,
    input  logic                 GLB_filter_valid,
    output logic                 GLB_filter_ready,
    input  logic                 GLB_ipsum_valid,
    output logic                 GLB_ipsum_ready,
    input  logic [DATA_SIZE-1:0] GLB_data_in,

    output logic                 GLB_opsum_valid,
    input  logic                 GLB_opsum_ready,
    output logic [DATA_SIZE-1:0] GLB_data_out
);

    localparam int NUMS_PE        = NUMS_PE_ROW * NUMS_PE_COL;
    localparam int NUMS_CLUSTER   = NUMS_CLUSTER_ROW * NUMS_CLUSTER_COL;
    localparam int PE_PER_CLUSTER = PE_ROW_PER_CLUSTER * PE_COL_PER_CLUSTER;

    initial begin
        if ((NUMS_PE_ROW % PE_ROW_PER_CLUSTER) != 0) begin
            $error("NUMS_PE_ROW must be divisible by PE_ROW_PER_CLUSTER");
        end
        if ((NUMS_PE_COL % PE_COL_PER_CLUSTER) != 0) begin
            $error("NUMS_PE_COL must be divisible by PE_COL_PER_CLUSTER");
        end
    end

    logic [NUMS_PE_ROW-2:0] ln_cfg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            ln_cfg <= '0;
        end
        else if (set_LN) begin
            ln_cfg <= LN_config_in;
        end
    end

    logic ifmap_gin_valid_i;
    logic filter_gin_valid_i;
    logic ipsum_gin_valid_i;
    logic ifmap_gin_ready_o;
    logic filter_gin_ready_o;
    logic ipsum_gin_ready_o;

    logic [NUMS_PE-1:0] ifmap_gin_valid;
    logic [NUMS_PE-1:0] ifmap_gin_ready;
    logic [DATA_SIZE-1:0] ifmap_gin_data;
    logic [NUMS_PE-1:0] filter_gin_valid;
    logic [NUMS_PE-1:0] filter_gin_ready;
    logic [DATA_SIZE-1:0] filter_gin_data;
    logic [NUMS_PE-1:0] ipsum_gin_valid;
    logic [NUMS_PE-1:0] ipsum_gin_ready;
    logic [DATA_SIZE-1:0] ipsum_gin_data;

    logic [NUMS_PE-1:0] gon_master_valid;
    logic [NUMS_PE-1:0] gon_master_ready;
    logic [DATA_SIZE*NUMS_PE-1:0] gon_master_data;

    assign ifmap_gin_valid_i  = GLB_ifmap_valid;
    assign filter_gin_valid_i = (!GLB_ifmap_valid) && GLB_filter_valid;
    assign ipsum_gin_valid_i  = (!GLB_ifmap_valid) && (!GLB_filter_valid) && GLB_ipsum_valid;

    assign GLB_ifmap_ready  = ifmap_gin_ready_o;
    assign GLB_filter_ready = (!GLB_ifmap_valid) ? filter_gin_ready_o : 1'b0;
    assign GLB_ipsum_ready  = (!GLB_ifmap_valid && !GLB_filter_valid) ? ipsum_gin_ready_o : 1'b0;

    GIN #(
        .NUMS_PE_ROW (NUMS_PE_ROW),
        .NUMS_PE_COL (NUMS_PE_COL),
        .DATA_SIZE   (DATA_SIZE),
        .XID_BITS    (XID_BITS),
        .YID_BITS    (YID_BITS)
    ) u_ifmap_gin (
        .clk         (clk),
        .rst         (rst),
        .GIN_valid   (ifmap_gin_valid_i),
        .GIN_ready   (ifmap_gin_ready_o),
        .GIN_data    (GLB_data_in),
        .tag_X       (ifmap_tag_X),
        .tag_Y       (ifmap_tag_Y),
        .set_XID     (set_XID),
        .XID_scan_in (ifmap_XID_scan_in),
        .set_YID     (set_YID),
        .YID_scan_in (ifmap_YID_scan_in),
        .PE_ready    (ifmap_gin_ready),
        .PE_valid    (ifmap_gin_valid),
        .PE_data     (ifmap_gin_data)
    );

    GIN #(
        .NUMS_PE_ROW (NUMS_PE_ROW),
        .NUMS_PE_COL (NUMS_PE_COL),
        .DATA_SIZE   (DATA_SIZE),
        .XID_BITS    (XID_BITS),
        .YID_BITS    (YID_BITS)
    ) u_filter_gin (
        .clk         (clk),
        .rst         (rst),
        .GIN_valid   (filter_gin_valid_i),
        .GIN_ready   (filter_gin_ready_o),
        .GIN_data    (GLB_data_in),
        .tag_X       (filter_tag_X),
        .tag_Y       (filter_tag_Y),
        .set_XID     (set_XID),
        .XID_scan_in (filter_XID_scan_in),
        .set_YID     (set_YID),
        .YID_scan_in (filter_YID_scan_in),
        .PE_ready    (filter_gin_ready),
        .PE_valid    (filter_gin_valid),
        .PE_data     (filter_gin_data)
    );

    GIN #(
        .NUMS_PE_ROW (NUMS_PE_ROW),
        .NUMS_PE_COL (NUMS_PE_COL),
        .DATA_SIZE   (DATA_SIZE),
        .XID_BITS    (XID_BITS),
        .YID_BITS    (YID_BITS)
    ) u_ipsum_gin (
        .clk         (clk),
        .rst         (rst),
        .GIN_valid   (ipsum_gin_valid_i),
        .GIN_ready   (ipsum_gin_ready_o),
        .GIN_data    (GLB_data_in),
        .tag_X       (ipsum_tag_X),
        .tag_Y       (ipsum_tag_Y),
        .set_XID     (set_XID),
        .XID_scan_in (ipsum_XID_scan_in),
        .set_YID     (set_YID),
        .YID_scan_in (ipsum_YID_scan_in),
        .PE_ready    (ipsum_gin_ready),
        .PE_valid    (ipsum_gin_valid),
        .PE_data     (ipsum_gin_data)
    );

    GON #(
        .NUMS_PE_ROW (NUMS_PE_ROW),
        .NUMS_PE_COL (NUMS_PE_COL),
        .DATA_SIZE   (DATA_SIZE),
        .XID_BITS    (XID_BITS),
        .YID_BITS    (YID_BITS)
    ) u_gon (
        .clk         (clk),
        .rst         (rst),
        .GON_valid   (GLB_opsum_valid),
        .GON_ready   (GLB_opsum_ready),
        .GON_data    (GLB_data_out),
        .tag_X       (opsum_tag_X),
        .tag_Y       (opsum_tag_Y),
        .set_XID     (set_XID),
        .XID_scan_in (opsum_XID_scan_in),
        .set_YID     (set_YID),
        .YID_scan_in (opsum_YID_scan_in),
        .PE_valid    (gon_master_valid),
        .PE_ready    (gon_master_ready),
        .PE_data     (gon_master_data)
    );

    logic [PE_PER_CLUSTER-1:0] cluster_PE_en [0:NUMS_CLUSTER-1];
    logic [PE_PER_CLUSTER-1:0] cluster_ifmap_valid [0:NUMS_CLUSTER-1];
    logic [PE_PER_CLUSTER-1:0] cluster_ifmap_ready [0:NUMS_CLUSTER-1];
    logic [PE_PER_CLUSTER-1:0] cluster_filter_valid [0:NUMS_CLUSTER-1];
    logic [PE_PER_CLUSTER-1:0] cluster_filter_ready [0:NUMS_CLUSTER-1];
    logic [PE_PER_CLUSTER-1:0] cluster_ipsum_valid [0:NUMS_CLUSTER-1];
    logic [PE_PER_CLUSTER-1:0] cluster_ipsum_ready [0:NUMS_CLUSTER-1];
    logic [PE_PER_CLUSTER-1:0] cluster_opsum_valid [0:NUMS_CLUSTER-1];
    logic [PE_PER_CLUSTER-1:0] cluster_opsum_ready [0:NUMS_CLUSTER-1];
    logic [DATA_SIZE*PE_PER_CLUSTER-1:0] cluster_opsum_data [0:NUMS_CLUSTER-1];

    logic [PE_ROW_PER_CLUSTER-1:0] cluster_ln_use_from_below [0:NUMS_CLUSTER-1];
    logic [PE_COL_PER_CLUSTER-1:0] cluster_ln_from_below_valid [0:NUMS_CLUSTER-1];
    logic [PE_COL_PER_CLUSTER-1:0] cluster_ln_from_below_ready [0:NUMS_CLUSTER-1];
    logic [DATA_SIZE*PE_COL_PER_CLUSTER-1:0] cluster_ln_from_below_data [0:NUMS_CLUSTER-1];
    logic [PE_COL_PER_CLUSTER-1:0] cluster_ln_to_above_enable [0:NUMS_CLUSTER-1];
    logic [PE_COL_PER_CLUSTER-1:0] cluster_ln_to_above_valid [0:NUMS_CLUSTER-1];
    logic [PE_COL_PER_CLUSTER-1:0] cluster_ln_to_above_ready [0:NUMS_CLUSTER-1];
    logic [DATA_SIZE*PE_COL_PER_CLUSTER-1:0] cluster_ln_to_above_data [0:NUMS_CLUSTER-1];

    genvar cr, cc, lr, lc;
    generate
        for (cr = 0; cr < NUMS_CLUSTER_ROW; cr = cr + 1) begin : GEN_CLUSTER_ROW
            for (cc = 0; cc < NUMS_CLUSTER_COL; cc = cc + 1) begin : GEN_CLUSTER_COL
                localparam int CIDX = cr * NUMS_CLUSTER_COL + cc;

                if (cr == 0) begin : GEN_TOP_CLUSTER_ROW
                    assign cluster_ln_to_above_enable[CIDX] = '0;
                    assign cluster_ln_to_above_ready[CIDX] = '0;
                end
                else begin : GEN_UPPER_CLUSTER_LN_CFG
                    assign cluster_ln_to_above_enable[CIDX] =
                        {PE_COL_PER_CLUSTER{ln_cfg[cr*PE_ROW_PER_CLUSTER-1]}};
                end

                if (cr == NUMS_CLUSTER_ROW-1) begin : GEN_BOTTOM_CLUSTER_ROW
                    assign cluster_ln_from_below_valid[CIDX] = '0;
                    assign cluster_ln_from_below_data[CIDX]  = '0;
                end
                else begin : GEN_CLUSTER_LN_LINK
                    localparam int BELOW_CIDX = (cr + 1) * NUMS_CLUSTER_COL + cc;
                    assign cluster_ln_from_below_valid[CIDX] = cluster_ln_to_above_valid[BELOW_CIDX];
                    assign cluster_ln_from_below_data[CIDX]  = cluster_ln_to_above_data[BELOW_CIDX];
                    assign cluster_ln_to_above_ready[BELOW_CIDX] = cluster_ln_from_below_ready[CIDX];
                end

                PE_cluster #(
                    .PE_ROW_PER_CLUSTER (PE_ROW_PER_CLUSTER),
                    .PE_COL_PER_CLUSTER (PE_COL_PER_CLUSTER),
                    .DATA_SIZE          (DATA_SIZE),
                    .CONFIG_SIZE        (CONFIG_SIZE)
                ) u_pe_cluster (
                    .clk                 (clk),
                    .rst                 (rst),
                    .PE_en               (cluster_PE_en[CIDX]),
                    .PE_config           (PE_config),
                    .ifmap_valid_i       (cluster_ifmap_valid[CIDX]),
                    .ifmap_ready_o       (cluster_ifmap_ready[CIDX]),
                    .ifmap_data_i        (ifmap_gin_data),
                    .filter_valid_i      (cluster_filter_valid[CIDX]),
                    .filter_ready_o      (cluster_filter_ready[CIDX]),
                    .filter_data_i       (filter_gin_data),
                    .ipsum_valid_i       (cluster_ipsum_valid[CIDX]),
                    .ipsum_ready_o       (cluster_ipsum_ready[CIDX]),
                    .ipsum_data_i        (ipsum_gin_data),
                    .ln_use_from_below   (cluster_ln_use_from_below[CIDX]),
                    .ln_from_below_valid (cluster_ln_from_below_valid[CIDX]),
                    .ln_from_below_ready (cluster_ln_from_below_ready[CIDX]),
                    .ln_from_below_data  (cluster_ln_from_below_data[CIDX]),
                    .ln_to_above_enable  (cluster_ln_to_above_enable[CIDX]),
                    .ln_to_above_valid   (cluster_ln_to_above_valid[CIDX]),
                    .ln_to_above_ready   (cluster_ln_to_above_ready[CIDX]),
                    .ln_to_above_data    (cluster_ln_to_above_data[CIDX]),
                    .opsum_valid_o       (cluster_opsum_valid[CIDX]),
                    .opsum_ready_i       (cluster_opsum_ready[CIDX]),
                    .opsum_data_o        (cluster_opsum_data[CIDX])
                );

                for (lr = 0; lr < PE_ROW_PER_CLUSTER; lr = lr + 1) begin : GEN_LROW_MAP
                    localparam int LN_GROW = cr * PE_ROW_PER_CLUSTER + lr;
                    assign cluster_ln_use_from_below[CIDX][lr] =
                        (LN_GROW < NUMS_PE_ROW-1) ? ln_cfg[LN_GROW] : 1'b0;

                    for (lc = 0; lc < PE_COL_PER_CLUSTER; lc = lc + 1) begin : GEN_LCOL_MAP
                        localparam int LIDX = lr * PE_COL_PER_CLUSTER + lc;
                        localparam int GROW = cr * PE_ROW_PER_CLUSTER + lr;
                        localparam int GCOL = cc * PE_COL_PER_CLUSTER + lc;
                        localparam int GIDX = GROW * NUMS_PE_COL + GCOL;

                        assign cluster_PE_en[CIDX][LIDX] = PE_en[GIDX];

                        assign cluster_ifmap_valid[CIDX][LIDX] = ifmap_gin_valid[GIDX];
                        assign ifmap_gin_ready[GIDX] = cluster_ifmap_ready[CIDX][LIDX];

                        assign cluster_filter_valid[CIDX][LIDX] = filter_gin_valid[GIDX];
                        assign filter_gin_ready[GIDX] = cluster_filter_ready[CIDX][LIDX];

                        assign cluster_ipsum_valid[CIDX][LIDX] = ipsum_gin_valid[GIDX];
                        assign ipsum_gin_ready[GIDX] = cluster_ipsum_ready[CIDX][LIDX];

                        assign gon_master_valid[GIDX] = cluster_opsum_valid[CIDX][LIDX];
                        assign cluster_opsum_ready[CIDX][LIDX] = gon_master_ready[GIDX];
                        assign gon_master_data[GIDX*DATA_SIZE +: DATA_SIZE] =
                            cluster_opsum_data[CIDX][LIDX*DATA_SIZE +: DATA_SIZE];
                    end
                end
            end
        end
    endgenerate

endmodule

`endif
