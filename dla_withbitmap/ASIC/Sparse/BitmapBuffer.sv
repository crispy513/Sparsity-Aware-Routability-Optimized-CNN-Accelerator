`ifndef DLA_BITMAP_BUFFER_SV
`define DLA_BITMAP_BUFFER_SV

module BitmapBuffer #(
    parameter int BLOCK_SIZE = 8,
    parameter int DEPTH      = 2048,
    parameter int ADDR_W     = (DEPTH <= 1) ? 1 : $clog2(DEPTH),
    parameter int COUNT_W    = (BLOCK_SIZE <= 1) ? 1 : $clog2(BLOCK_SIZE + 1)
)(
    input  logic                  clk,
    input  logic                  rst,

    input  logic                  host_wr_en,
    input  logic [ADDR_W-1:0]     host_wr_addr,
    input  logic [BLOCK_SIZE-1:0] host_bitmap_wdata,
    input  logic [COUNT_W-1:0]    host_nz_count_wdata,
    input  logic                  host_rd_en,
    input  logic [ADDR_W-1:0]     host_rd_addr,
    output logic [BLOCK_SIZE-1:0] host_bitmap_rdata,
    output logic [COUNT_W-1:0]    host_nz_count_rdata,

    input  logic                  start_capture,
    input  logic [ADDR_W-1:0]     capture_base,
    input  logic [ADDR_W:0]       capture_len,
    output logic                  capture_busy,
    output logic                  capture_done,
    input  logic [BLOCK_SIZE-1:0] enc_bitmap_i,
    input  logic [COUNT_W-1:0]    enc_nz_count_i,
    input  logic                  enc_valid_i,
    output logic                  enc_ready_o,

    input  logic                  start_stream,
    input  logic [ADDR_W-1:0]     stream_base,
    input  logic [ADDR_W:0]       stream_len,
    output logic                  stream_busy,
    output logic                  stream_done,
    output logic [BLOCK_SIZE-1:0] dec_bitmap_o,
    output logic [COUNT_W-1:0]    dec_nz_count_o,
    output logic                  dec_valid_o,
    input  logic                  dec_ready_i
);

    logic [BLOCK_SIZE-1:0] bitmap_mem   [0:DEPTH-1];
    logic [COUNT_W-1:0]    nz_count_mem [0:DEPTH-1];

    logic [ADDR_W-1:0] cap_ptr_q, cap_ptr_d;
    logic [ADDR_W:0]   cap_left_q, cap_left_d;
    logic              cap_en_q, cap_en_d;

    logic [ADDR_W-1:0] str_ptr_q, str_ptr_d;
    logic [ADDR_W:0]   str_left_q, str_left_d;

    logic enc_fire;
    logic dec_fire;

    always_comb begin
        host_bitmap_rdata   = '0;
        host_nz_count_rdata = '0;
        if (host_rd_en) begin
            host_bitmap_rdata   = bitmap_mem[host_rd_addr];
            host_nz_count_rdata = nz_count_mem[host_rd_addr];
        end
    end

    always_comb begin
        cap_ptr_d    = cap_ptr_q;
        cap_left_d   = cap_left_q;
        cap_en_d     = cap_en_q;
        capture_done = 1'b0;

        if (start_capture && !cap_en_q) begin
            cap_ptr_d  = capture_base;
            cap_left_d = capture_len;
            cap_en_d   = (capture_len != '0);
        end
        else if (enc_fire) begin
            cap_ptr_d  = cap_ptr_q + 1'b1;
            cap_left_d = cap_left_q - 1'b1;
            if (cap_left_q == {{ADDR_W{1'b0}}, 1'b1}) begin
                cap_en_d     = 1'b0;
                capture_done = 1'b1;
            end
        end
    end

    assign capture_busy = cap_en_q;
    assign enc_ready_o  = cap_en_q && (cap_left_q != '0);
    assign enc_fire     = enc_valid_i & enc_ready_o;

    always_comb begin
        str_ptr_d   = str_ptr_q;
        str_left_d  = str_left_q;
        stream_done = 1'b0;

        if (start_stream && !stream_busy) begin
            str_ptr_d  = stream_base;
            str_left_d = stream_len;
        end
        else if (dec_fire) begin
            str_ptr_d  = str_ptr_q + 1'b1;
            str_left_d = str_left_q - 1'b1;
            if (str_left_q == {{ADDR_W{1'b0}}, 1'b1}) begin
                stream_done = 1'b1;
            end
        end
    end

    assign stream_busy    = (str_left_q != '0);
    assign dec_valid_o    = (str_left_q != '0);
    assign dec_bitmap_o   = bitmap_mem[str_ptr_q];
    assign dec_nz_count_o = nz_count_mem[str_ptr_q];
    assign dec_fire       = dec_valid_o & dec_ready_i;

    always_ff @(posedge clk) begin
        if (enc_fire) begin
            bitmap_mem[cap_ptr_q]   <= enc_bitmap_i;
            nz_count_mem[cap_ptr_q] <= enc_nz_count_i;
        end
        else if (host_wr_en) begin
            bitmap_mem[host_wr_addr]   <= host_bitmap_wdata;
            nz_count_mem[host_wr_addr] <= host_nz_count_wdata;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            cap_ptr_q  <= '0;
            cap_left_q <= '0;
            cap_en_q   <= 1'b0;
            str_ptr_q  <= '0;
            str_left_q <= '0;
        end
        else begin
            cap_ptr_q  <= cap_ptr_d;
            cap_left_q <= cap_left_d;
            cap_en_q   <= cap_en_d;
            str_ptr_q  <= str_ptr_d;
            str_left_q <= str_left_d;
        end
    end

endmodule

`endif
