module GON_Bus_full_throughput_pipeline #(
    parameter NUMS_MASTER = 8,
    parameter TAG_SIZE = 6,
    parameter PAYLOAD_TAG_SIZE = 1,
    parameter DATA_SIZE = 32,
    parameter USE_MASTER_TAG = 0
) (
    input clk,
    input rst,

    input [TAG_SIZE - 1:0] tag,
    input issue_valid,
    input advance_tag,
    input next_tag_valid,
    input [TAG_SIZE - 1:0] next_tag,
    input [PAYLOAD_TAG_SIZE - 1:0] payload_tag,
    input [PAYLOAD_TAG_SIZE - 1:0] next_payload_tag,
    input [NUMS_MASTER * TAG_SIZE - 1:0] master_tag,

    input [NUMS_MASTER - 1:0] master_valid,
    input [NUMS_MASTER * DATA_SIZE - 1:0] master_data,
    output logic [NUMS_MASTER - 1:0] master_ready,

    output logic slave_valid,
    input slave_ready,
    output logic [DATA_SIZE - 1:0] slave_data,
    output logic [PAYLOAD_TAG_SIZE - 1:0] slave_payload_tag,
    output logic input_fire,

    // Config
    input set_id,
    input [TAG_SIZE - 1:0] ID_scan_in,
    output logic [TAG_SIZE - 1:0] ID_scan_out
);

logic tag_valid;
logic [TAG_SIZE - 1:0] tag_pipe;
logic [PAYLOAD_TAG_SIZE - 1:0] payload_tag_pipe;
logic [NUMS_MASTER - 1:0] mc_valid;
logic [NUMS_MASTER - 1:0] mc_ready;
logic selected_valid;
logic selected_ready;
logic [DATA_SIZE - 1:0] selected_data;
logic [PAYLOAD_TAG_SIZE - 1:0] selected_payload_tag;
logic pipe_valid;
logic [DATA_SIZE - 1:0] pipe_data;
logic [PAYLOAD_TAG_SIZE - 1:0] pipe_payload_tag;

/* verilator lint_off UNOPTFLAT */
logic [DATA_SIZE - 1:0] select_data [0:NUMS_MASTER];
logic [TAG_SIZE - 1:0] ID_scan_chain [0:NUMS_MASTER];
/* verilator lint_on UNOPTFLAT */

assign ID_scan_chain[NUMS_MASTER] = ID_scan_in;
assign select_data[0] = 'd0;

always_ff @(posedge clk) begin
    if (rst) begin
        tag_valid <= 1'b0;
        tag_pipe <= 'd0;
        payload_tag_pipe <= 'd0;
    end
    else if (advance_tag) begin
        tag_valid <= next_tag_valid;
        if (next_tag_valid) begin
            tag_pipe <= next_tag;
            payload_tag_pipe <= next_payload_tag;
        end
    end
    else if (!tag_valid && issue_valid) begin
        tag_valid <= 1'b1;
        tag_pipe <= tag;
        payload_tag_pipe <= payload_tag;
    end
end

always_ff @(posedge clk) begin
    if (rst) begin
        pipe_valid <= 1'b0;
        pipe_data <= 'd0;
        pipe_payload_tag <= 'd0;
    end
    else if (selected_ready) begin
        pipe_valid <= selected_valid;
        if (selected_valid) begin
            pipe_data <= selected_data;
            pipe_payload_tag <= selected_payload_tag;
        end
    end
end

assign selected_ready = ~pipe_valid || slave_ready;
assign selected_valid = |mc_valid;
assign selected_data = (selected_valid)? select_data[NUMS_MASTER]: 'd0;
assign selected_payload_tag = payload_tag_pipe;
assign input_fire = selected_valid && selected_ready;

assign slave_valid = pipe_valid;
assign slave_data = (pipe_valid)? pipe_data: 'd0;
assign slave_payload_tag = pipe_payload_tag;

generate
genvar i;
for (i = 0; i < NUMS_MASTER; i++) begin : GON_FT_MC
    logic [TAG_SIZE - 1:0] compare_tag;
    logic compare_valid;

    assign compare_tag = (USE_MASTER_TAG)?
                         master_tag[(i+1)*TAG_SIZE-1:i*TAG_SIZE]:
                         tag_pipe;
    assign compare_valid = (USE_MASTER_TAG)? 1'b1: (tag_valid && issue_valid);

    GON_MulticastController #(
        .ID_SIZE(TAG_SIZE),
        .DATA_SIZE(DATA_SIZE)
    ) MC_i (
        .clk(clk),
        .rst(rst),
        .set_id(set_id),
        .id_in(ID_scan_chain[i+1]),
        .id(ID_scan_chain[i]),
        .tag(compare_tag),
        .valid_in(compare_valid && master_valid[i]),
        .valid_out(mc_valid[i]),
        .ready_in(selected_ready),
        .ready_out(mc_ready[i])
    );

    assign master_ready[i] = mc_ready[i] && compare_valid;
    assign select_data[i+1] = (mc_valid[i])?
                              select_data[i] | master_data[(i+1)*DATA_SIZE-1:i*DATA_SIZE]:
                              select_data[i];
end
endgenerate

assign ID_scan_out = ID_scan_chain[0];

endmodule
