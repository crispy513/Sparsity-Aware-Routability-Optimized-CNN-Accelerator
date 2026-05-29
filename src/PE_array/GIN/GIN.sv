`ifndef GIN_V
`define GIN_V

`include "define.svh"
`include "src/PE_array/GIN/GIN_Bus.sv"

module GIN #(
    parameter int NUMS_PE_ROW = `NUMS_PE_ROW,
    parameter int NUMS_PE_COL = `NUMS_PE_COL,
    parameter int DATA_SIZE   = `DATA_BITS,
    parameter int XID_BITS    = `XID_BITS,
    parameter int YID_BITS    = `YID_BITS
)(
    input  logic clk,
    input  logic rst,

    input  logic GIN_valid,
    output logic GIN_ready,
    input  logic [DATA_SIZE-1:0] GIN_data,

    input  logic [XID_BITS-1:0] tag_X,
    input  logic [YID_BITS-1:0] tag_Y,

    input  logic set_XID,
    input  logic [XID_BITS-1:0] XID_scan_in,
    input  logic set_YID,
    input  logic [YID_BITS-1:0] YID_scan_in,

    input  logic [NUMS_PE_ROW*NUMS_PE_COL-1:0] PE_ready,
    output logic [NUMS_PE_ROW*NUMS_PE_COL-1:0] PE_valid,
    output logic [DATA_SIZE-1:0] PE_data
);

    logic [NUMS_PE_ROW-1:0] row_valid;
    logic [NUMS_PE_ROW-1:0] row_ready;
    logic [DATA_SIZE-1:0]   row_data;

    logic [YID_BITS-1:0] yid_scan_out_unused;
    logic [XID_BITS-1:0] xid_scan_chain [0:NUMS_PE_ROW];

    genvar r;

    assign xid_scan_chain[0] = XID_scan_in;
    assign PE_data           = row_data;

    GIN_Bus #(
        .NUMS_SLAVE       (NUMS_PE_ROW),
        .ID_SIZE          (YID_BITS),
        .DATA_SIZE        (DATA_SIZE),
        .STATIC_ID_ENABLE (1'b0)
    ) u_y_bus (
        .clk          (clk),
        .rst          (rst),
        .tag          (tag_Y),
        .master_valid (GIN_valid),
        .master_data  (GIN_data),
        .master_ready (GIN_ready),
        .slave_ready  (row_ready),
        .slave_valid  (row_valid),
        .slave_data   (row_data),
        .set_id       (set_YID),
        .ID_scan_in   (YID_scan_in),
        .ID_scan_out  (yid_scan_out_unused)
    );

    generate
        for (r = 0; r < NUMS_PE_ROW; r = r + 1) begin : GEN_X_BUS
            GIN_Bus #(
                .NUMS_SLAVE       (NUMS_PE_COL),
                .ID_SIZE          (XID_BITS),
                .DATA_SIZE        (DATA_SIZE),
                .STATIC_ID_ENABLE (1'b0)
            ) u_x_bus (
                .clk          (clk),
                .rst          (rst),
                .tag          (tag_X),
                .master_valid (row_valid[r]),
                .master_data  (row_data),
                .master_ready (row_ready[r]),
                .slave_ready  (PE_ready[r*NUMS_PE_COL +: NUMS_PE_COL]),
                .slave_valid  (PE_valid[r*NUMS_PE_COL +: NUMS_PE_COL]),
                .slave_data   (),
                .set_id       (set_XID),
                .ID_scan_in   (xid_scan_chain[r]),
                .ID_scan_out  (xid_scan_chain[r+1])
            );
        end
    endgenerate

endmodule

`endif
