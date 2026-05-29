`ifndef PE_CLUSTER_SV
`define PE_CLUSTER_SV

`include "define.svh"
`include "src/PE_array/PE.sv"

module PE_cluster #(
    parameter int PE_ROW_PER_CLUSTER = 2,
    parameter int PE_COL_PER_CLUSTER = 2,
    parameter int DATA_SIZE          = `DATA_BITS,
    parameter int CONFIG_SIZE        = `CONFIG_SIZE
)(
    input  logic clk,
    input  logic rst,

    input  logic [PE_ROW_PER_CLUSTER*PE_COL_PER_CLUSTER-1:0] PE_en,
    input  logic [CONFIG_SIZE-1:0] PE_config,

    input  logic [PE_ROW_PER_CLUSTER*PE_COL_PER_CLUSTER-1:0] ifmap_valid_i,
    output logic [PE_ROW_PER_CLUSTER*PE_COL_PER_CLUSTER-1:0] ifmap_ready_o,
    input  logic [DATA_SIZE-1:0] ifmap_data_i,

    input  logic [PE_ROW_PER_CLUSTER*PE_COL_PER_CLUSTER-1:0] filter_valid_i,
    output logic [PE_ROW_PER_CLUSTER*PE_COL_PER_CLUSTER-1:0] filter_ready_o,
    input  logic [DATA_SIZE-1:0] filter_data_i,

    input  logic [PE_ROW_PER_CLUSTER*PE_COL_PER_CLUSTER-1:0] ipsum_valid_i,
    output logic [PE_ROW_PER_CLUSTER*PE_COL_PER_CLUSTER-1:0] ipsum_ready_o,
    input  logic [DATA_SIZE-1:0] ipsum_data_i,

    input  logic [PE_ROW_PER_CLUSTER-1:0] ln_use_from_below,
    input  logic [PE_COL_PER_CLUSTER-1:0] ln_from_below_valid,
    output logic [PE_COL_PER_CLUSTER-1:0] ln_from_below_ready,
    input  logic [DATA_SIZE*PE_COL_PER_CLUSTER-1:0] ln_from_below_data,
    input  logic [PE_COL_PER_CLUSTER-1:0] ln_to_above_enable,
    output logic [PE_COL_PER_CLUSTER-1:0] ln_to_above_valid,
    input  logic [PE_COL_PER_CLUSTER-1:0] ln_to_above_ready,
    output logic [DATA_SIZE*PE_COL_PER_CLUSTER-1:0] ln_to_above_data,

    output logic [PE_ROW_PER_CLUSTER*PE_COL_PER_CLUSTER-1:0] opsum_valid_o,
    input  logic [PE_ROW_PER_CLUSTER*PE_COL_PER_CLUSTER-1:0] opsum_ready_i,
    output logic [DATA_SIZE*PE_ROW_PER_CLUSTER*PE_COL_PER_CLUSTER-1:0] opsum_data_o
);

    localparam int NUMS_LOCAL_PE = PE_ROW_PER_CLUSTER * PE_COL_PER_CLUSTER;

    logic [NUMS_LOCAL_PE-1:0] pe_ipsum_ready;
    logic [NUMS_LOCAL_PE-1:0] pe_opsum_valid;
    logic [NUMS_LOCAL_PE-1:0] pe_opsum_ready;
    logic [DATA_SIZE*NUMS_LOCAL_PE-1:0] pe_opsum_data;

    genvar r, c;
    generate
        for (r = 0; r < PE_ROW_PER_CLUSTER; r = r + 1) begin : GEN_LOCAL_ROW
            for (c = 0; c < PE_COL_PER_CLUSTER; c = c + 1) begin : GEN_LOCAL_COL
                localparam int LIDX = r * PE_COL_PER_CLUSTER + c;

                logic [DATA_SIZE-1:0] ipsum_sel_data;
                logic                 ipsum_sel_valid;
                logic                 use_ln_from_below;
                logic                 feed_ln_up;

                assign use_ln_from_below = ln_use_from_below[r];

                if (r == PE_ROW_PER_CLUSTER-1) begin : GEN_BOTTOM_LN_IN
                    assign ipsum_sel_data         = use_ln_from_below ? ln_from_below_data[c*DATA_SIZE +: DATA_SIZE] : ipsum_data_i;
                    assign ipsum_sel_valid        = use_ln_from_below ? ln_from_below_valid[c] : ipsum_valid_i[LIDX];
                    assign ln_from_below_ready[c] = use_ln_from_below ? pe_ipsum_ready[LIDX] : 1'b0;
                end
                else begin : GEN_LOCAL_LN_IN
                    localparam int BELOW_IDX = (r + 1) * PE_COL_PER_CLUSTER + c;
                    assign ipsum_sel_data  = use_ln_from_below ? pe_opsum_data[BELOW_IDX*DATA_SIZE +: DATA_SIZE] : ipsum_data_i;
                    assign ipsum_sel_valid = use_ln_from_below ? pe_opsum_valid[BELOW_IDX] : ipsum_valid_i[LIDX];
                end

                assign ipsum_ready_o[LIDX] = use_ln_from_below ? 1'b1 : pe_ipsum_ready[LIDX];

                if (r == 0) begin : GEN_TOP_LN_OUT
                    assign feed_ln_up = ln_to_above_enable[c];
                    assign ln_to_above_valid[c] = pe_opsum_valid[LIDX];
                    assign ln_to_above_data[c*DATA_SIZE +: DATA_SIZE] = pe_opsum_data[LIDX*DATA_SIZE +: DATA_SIZE];
                    assign pe_opsum_ready[LIDX] = feed_ln_up ? ln_to_above_ready[c] : opsum_ready_i[LIDX];
                end
                else begin : GEN_LOCAL_LN_OUT
                    localparam int ABOVE_IDX = (r - 1) * PE_COL_PER_CLUSTER + c;
                    assign feed_ln_up = ln_use_from_below[r-1];
                    assign pe_opsum_ready[LIDX] = feed_ln_up ? pe_ipsum_ready[ABOVE_IDX] : opsum_ready_i[LIDX];
                end

                assign opsum_valid_o[LIDX] = feed_ln_up ? 1'b0 : pe_opsum_valid[LIDX];
                assign opsum_data_o[LIDX*DATA_SIZE +: DATA_SIZE] = pe_opsum_data[LIDX*DATA_SIZE +: DATA_SIZE];

                PE u_pe (
                    .clk          (clk),
                    .rst          (rst),
                    .PE_en        (PE_en[LIDX]),
                    .i_config     (PE_config),
                    .ifmap        (ifmap_data_i),
                    .filter       (filter_data_i),
                    .ipsum        (ipsum_sel_data),
                    .ifmap_valid  (ifmap_valid_i[LIDX]),
                    .filter_valid (filter_valid_i[LIDX]),
                    .ipsum_valid  (ipsum_sel_valid),
                    .opsum_ready  (pe_opsum_ready[LIDX]),
                    .opsum        (pe_opsum_data[LIDX*DATA_SIZE +: DATA_SIZE]),
                    .ifmap_ready  (ifmap_ready_o[LIDX]),
                    .filter_ready (filter_ready_o[LIDX]),
                    .ipsum_ready  (pe_ipsum_ready[LIDX]),
                    .opsum_valid  (pe_opsum_valid[LIDX])
                );
            end
        end
    endgenerate

endmodule

`endif
