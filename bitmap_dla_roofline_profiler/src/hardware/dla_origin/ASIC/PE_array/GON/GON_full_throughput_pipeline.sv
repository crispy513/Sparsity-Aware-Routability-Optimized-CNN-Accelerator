//`include "src/PE_array/GON/GON_MulticastController.sv"
//`include "src/PE_array/GON/GON_Bus_full_throughput_pipeline.sv"
module GON_full_throughput_pipeline #(
    parameter NUMS_XBUS = 6,
    parameter NUMS_PE = 8,
    parameter XID_SIZE = 4,
    parameter YID_SIZE = 3,
    parameter DATA_SIZE = 32,
    parameter FIFO_DEPTH = 8
) (
    input clk,
    input rst,

    /* Master GON <-> GLB */
    output logic GON_valid,
    input GON_ready,
    output logic [DATA_SIZE-1:0] GON_data,

    /* Controller <-> GON */
    input GON_issue_valid,
    input GON_issue_ready,
    output logic GON_issue_fire,
    input GON_next_issue_valid,
    input [XID_SIZE-1:0] tag_X,
    input [YID_SIZE-1:0] tag_Y,
    input [XID_SIZE-1:0] next_tag_X,
    input [YID_SIZE-1:0] next_tag_Y,

    /* config */
    input set_XID,
    input [XID_SIZE - 1:0] XID_scan_in,
    input set_YID,
    input [YID_SIZE - 1:0] YID_scan_in,

    // Master PE <-> GON
    input [NUMS_XBUS * NUMS_PE - 1:0] PE_valid,
    output logic [NUMS_XBUS * NUMS_PE - 1:0] PE_ready,
    input [DATA_SIZE * NUMS_XBUS * NUMS_PE - 1:0] PE_data
);

logic issue_enable;
logic y_tag_valid;
logic [YID_SIZE-1:0] y_tag_pipe;
logic [NUMS_XBUS-1:0] XBus_valid;
logic [NUMS_XBUS-1:0] XBus_ready;
logic [NUMS_XBUS-1:0] XBus_input_fire;
logic [NUMS_XBUS*DATA_SIZE-1:0] XBus_data;
logic [XID_SIZE-1:0] XID_scan_chain [0:NUMS_XBUS];
logic [YID_SIZE-1:0] YBus_payload_unused;
logic [XID_SIZE-1:0] XBus_master_tag_unused;
logic [YID_SIZE-1:0] YBus_tag_unused;

assign issue_enable = GON_issue_valid && GON_issue_ready;
assign GON_issue_fire = |XBus_input_fire;
assign XID_scan_chain[NUMS_XBUS] = XID_scan_in;
assign XBus_master_tag_unused = 'd0;
assign YBus_tag_unused = 'd0;

always_ff @(posedge clk) begin
    if (rst) begin
        y_tag_valid <= 1'b0;
        y_tag_pipe <= 'd0;
    end
    else if (GON_issue_fire) begin
        y_tag_valid <= GON_next_issue_valid;
        if (GON_next_issue_valid) y_tag_pipe <= next_tag_Y;
    end
    else if (!y_tag_valid && GON_issue_valid) begin
        y_tag_valid <= 1'b1;
        y_tag_pipe <= tag_Y;
    end
end

GON_Bus_full_throughput_pipeline #(
    .NUMS_MASTER(NUMS_XBUS),
    .TAG_SIZE(YID_SIZE),
    .PAYLOAD_TAG_SIZE(YID_SIZE),
    .DATA_SIZE(DATA_SIZE),
    .USE_MASTER_TAG(1)
) Y_Bus (
    .clk(clk),
    .rst(rst),
    .tag(YBus_tag_unused),
    .issue_valid(y_tag_valid),
    .advance_tag(1'b0),
    .next_tag_valid(1'b0),
    .next_tag({YID_SIZE{1'b0}}),
    .payload_tag({YID_SIZE{1'b0}}),
    .next_payload_tag({YID_SIZE{1'b0}}),
    .master_tag({NUMS_XBUS{y_tag_pipe}}),
    // Bus
    .master_valid(XBus_valid),
    .master_data(XBus_data),
    .master_ready(XBus_ready),
    // GLB
    .slave_valid(GON_valid),
    .slave_ready(GON_ready),
    .slave_data(GON_data),
    .slave_payload_tag(YBus_payload_unused),
    .input_fire(),
    .set_id(set_YID),
    .ID_scan_in(YID_scan_in),
    .ID_scan_out()
);

generate
genvar i;
for (i = 0; i < NUMS_XBUS; i++) begin : GON_XBUS
    GON_Bus_full_throughput_pipeline #(
        .NUMS_MASTER(NUMS_PE),
        .TAG_SIZE(XID_SIZE),
        .PAYLOAD_TAG_SIZE(YID_SIZE),
        .DATA_SIZE(DATA_SIZE),
        .USE_MASTER_TAG(0)
    ) XBus (
        .clk(clk),
        .rst(rst),
        .tag(tag_X),
        .issue_valid(issue_enable),
        .advance_tag(GON_issue_fire),
        .next_tag_valid(GON_next_issue_valid),
        .next_tag(next_tag_X),
        .payload_tag(tag_Y),
        .next_payload_tag(next_tag_Y),
        .master_tag({NUMS_PE{XBus_master_tag_unused}}),
        // PE
        .master_valid(PE_valid[(i+1)*NUMS_PE-1:i*NUMS_PE]),
        .master_data(PE_data[(i+1)*NUMS_PE*DATA_SIZE-1:i*NUMS_PE*DATA_SIZE]),
        .master_ready(PE_ready[(i+1)*NUMS_PE-1:i*NUMS_PE]),
        // Bus
        .slave_valid(XBus_valid[i]),
        .slave_ready(XBus_ready[i]),
        .slave_data(XBus_data[(i+1)*DATA_SIZE-1:i*DATA_SIZE]),
        .slave_payload_tag(),
        .input_fire(XBus_input_fire[i]),
        .set_id(set_XID),
        .ID_scan_in(XID_scan_chain[i+1]),
        .ID_scan_out(XID_scan_chain[i])
    );
end
endgenerate

endmodule
