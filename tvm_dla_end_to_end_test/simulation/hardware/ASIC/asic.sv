`include "AXI_define.svh"
`include "ASIC.svh"
`include "ASIC/Sparse/BitmapBuffer.sv"

module asic #(
    parameter FULL_THROUGHPUT_GON = 1,
    parameter GON_FIFO_DEPTH = 8
) (
    input clk,
    input rst,
    input asic_en,
    input maxpool_i,
    input relu_i,
    input operation_mode_i,
    input [5:0] scaling_factor_i,
    input ifmap_sparse_en_i,

    /* mapping parameters */
    input [9:0] m_i, // number of ofmap channels stored in GLB
    input [3:0] e_i, // width of the PE sets
    input [2:0] p_i, // number of filters processed by a PE set
    input [2:0] q_i, // number of channels processed by a PE
    input [2:0] r_i, // number of PE sets that process different channels in the PE arrays
    input [2:0] t_i, // number of PE sets that process different filters in the PE arrays

    /* shape parameters */
    input [9:0] C_i,
    input [9:0] M_i,
    input [7:0] W_i,
    input [7:0] H_i,

    /* DRAM config */
    input [`AXI_ADDR_BITS-1:0] ifmap_addr_i,
    input [`AXI_ADDR_BITS-1:0] filter_addr_i,
    input [`AXI_ADDR_BITS-1:0] bias_addr_i,
    input [`AXI_ADDR_BITS-1:0] ofmap_addr_i,

    // staring address in GLB (Note: GLB_ifmap_addr = 0)
    input [`GLB_ADDR_BITS-1:0] GLB_filter_addr_i,
    input [`GLB_ADDR_BITS-1:0] GLB_bias_addr_i,
    input [`GLB_ADDR_BITS-1:0] GLB_opsum_addr_i,

    /* GLB */
    output logic GLB_EN,
    output logic GLB_WEB,
    output logic GLB_MODE,
    output logic [`GLB_ADDR_BITS-1:0] GLB_A,
    output logic [`DATA_BITS-1:0] GLB_DI,
    input [`DATA_BITS-1:0] GLB_DO,
    output logic GLB_mux,

    /* Sparse bitmap metadata */
    input sparse_bitmap_wr_en,
    input [1:0] sparse_bitmap_wr_sel,
    input [`SPARSE_BMAP_ADDR_BITS-1:0] sparse_bitmap_wr_addr,
    input [`SPARSE_BLOCK_SIZE-1:0] sparse_bitmap_wr_data,
    input [`SPARSE_COUNT_BITS-1:0] sparse_bitmap_wr_nz_count,
    input [1:0] sparse_bitmap_rd_sel,
    input [`SPARSE_BMAP_ADDR_BITS-1:0] sparse_bitmap_rd_addr,
    output logic [`SPARSE_BLOCK_SIZE-1:0] sparse_bitmap_rd_data,
    output logic [`SPARSE_COUNT_BITS-1:0] sparse_bitmap_rd_nz_count,
    input sparse_len_wr_en,
    input [1:0] sparse_len_wr_sel,
    input [`SPARSE_BMAP_ADDR_BITS-1:0] sparse_len_wr_addr,
    input [`GLB_ADDR_BITS-1:0] sparse_len_wr_data,
    input [1:0] sparse_len_rd_sel,
    input [`SPARSE_BMAP_ADDR_BITS-1:0] sparse_len_rd_addr,
    output logic [`GLB_ADDR_BITS-1:0] sparse_len_rd_data,

    /* DMA */
    output logic DMA_en,
    output logic [1:0] DMA_mode,
    output logic [`AXI_ADDR_BITS-1:0] DMA_DRAM_ADDR,
    output logic [`GLB_ADDR_BITS-1:0] DMA_GLB_ADDR,
    output logic [`GLB_ADDR_BITS-1:0] DMA_len,
    output logic [1:0] DMA_byte_bias,
    input DMA_done,

    output logic asic_interrupt
);

/*******************************************
    PE - array
********************************************/
logic [`DATA_BITS-1:0] GLB_data_out_PEarray;
logic [`DATA_BITS-1:0] GLB_data_in_PEarray;
logic [`DATA_BITS-1:0] GLB_data_in_sparse;
logic [`DATA_BITS-1:0] GLB_data_out_sparse;
logic ifmap_bitmap_valid;
logic ifmap_bitmap_ready;
logic ifmap_cmp_valid;
logic ifmap_cmp_ready;
logic [`DATA_BITS-1:0] ifmap_decoded_data;
logic ifmap_is_padding;
logic [`DATA_BITS-1:0] ifmap_to_pe;

logic ctrl_GLB_EN;
logic ctrl_GLB_WEB;
logic ctrl_GLB_MODE;
logic [`GLB_ADDR_BITS-1:0] ctrl_GLB_A;
logic ctrl_GLB_mux;
logic [1:0] sparse_read_sel;
logic ctrl_DMA_en;
logic [1:0] ctrl_DMA_mode;
logic [`AXI_ADDR_BITS-1:0] ctrl_DMA_DRAM_ADDR;
logic [`GLB_ADDR_BITS-1:0] ctrl_DMA_GLB_ADDR;
logic [`GLB_ADDR_BITS-1:0] ctrl_DMA_len;
logic [1:0] ctrl_DMA_byte_bias;
logic ctrl_DMA_done;

logic set_XID;
logic [`XID_BITS-1:0] ifmap_XID_scan_in;
logic [`XID_BITS-1:0] filter_XID_scan_in;
logic [`XID_BITS-1:0] ipsum_XID_scan_in;
logic [`XID_BITS-1:0] opsum_XID_scan_in;
logic set_YID;
logic [`YID_BITS-1:0] ifmap_YID_scan_in;
logic [`YID_BITS-1:0] filter_YID_scan_in;
logic [`YID_BITS-1:0] ipsum_YID_scan_in;
logic [`YID_BITS-1:0] opsum_YID_scan_in;
logic set_LN;
logic [`PE_ARRAY_H-2:0] LN_config_in;

logic [`PE_ARRAY_H*`PE_ARRAY_W-1:0] PE_en;
logic [10:0] PE_config;

logic PEA_ifmap_valid;
logic PEA_ifmap_ready;
logic PEA_ifmap_valid_array;
logic PEA_ifmap_ready_array;
logic [`XID_BITS-1:0] ifmap_tag_X;
logic [`YID_BITS-1:0] ifmap_tag_Y;

logic PEA_filter_valid;
logic PEA_filter_ready;
logic PEA_filter_valid_array;
logic PEA_filter_ready_array;
logic [`XID_BITS-1:0] filter_tag_X;
logic [`YID_BITS-1:0] filter_tag_Y;

logic PEA_ipsum_valid;
logic PEA_ipsum_ready;
logic PEA_ipsum_valid_array;
logic PEA_ipsum_ready_array;
logic [`XID_BITS-1:0] ipsum_tag_X;
logic [`YID_BITS-1:0] ipsum_tag_Y;

logic PEA_opsum_valid;
logic PEA_opsum_ready;
logic [`XID_BITS-1:0] opsum_tag_X;
logic [`YID_BITS-1:0] opsum_tag_Y;
logic [`XID_BITS-1:0] opsum_next_tag_X;
logic [`YID_BITS-1:0] opsum_next_tag_Y;
logic opsum_next_tag_valid;
logic PEA_opsum_issue_valid;
logic PEA_opsum_issue_ready;
logic PEA_opsum_issue_fire;

logic GLB_DI_select;
logic GLB_DO_select;

logic asic_en_q;
logic ctrl_DMA_en_q;
logic [1:0] ctrl_DMA_mode_q;
logic [1:0] sparse_read_sel_q;
logic sparse_start;
logic filter_dma_group_start;
logic filter_read_group_start;
logic ifmap_replay_start;
logic sparse_ifmap_bit;
logic sparse_filter_bit;
logic sparse_ipsum_bit;
logic sparse_selected_nonzero;
logic sparse_selected_valid;
logic sparse_selected_fire;
logic sparse_selected_consumes_bitmap;
logic sparse_selected_pad;

logic [`GLB_ADDR_BITS-3:0] ifmap_cmp_ptr;
logic [`GLB_ADDR_BITS-3:0] filter_cmp_ptr;
logic [`GLB_ADDR_BITS-3:0] ipsum_cmp_ptr;
logic [`GLB_ADDR_BITS-3:0] opsum_cmp_ptr;

logic [$clog2(`SPARSE_BLOCK_SIZE)-1:0] ifmap_bit_idx;
logic [$clog2(`SPARSE_BLOCK_SIZE)-1:0] filter_bit_idx;
logic [$clog2(`SPARSE_BLOCK_SIZE)-1:0] ipsum_bit_idx;
logic [$clog2(`SPARSE_BLOCK_SIZE)-1:0] opsum_bit_idx;
logic [`SPARSE_BLOCK_SIZE-1:0] opsum_bitmap_q;
logic [`SPARSE_COUNT_BITS-1:0] opsum_nz_count_q;

logic ifmap_bmap_valid, ifmap_bmap_ready;
logic [`SPARSE_BLOCK_SIZE-1:0] ifmap_bmap_data;
logic [`SPARSE_COUNT_BITS-1:0] ifmap_bmap_nz;
logic filter_bmap_valid, filter_bmap_ready;
logic [`SPARSE_BLOCK_SIZE-1:0] filter_bmap_data;
logic [`SPARSE_COUNT_BITS-1:0] filter_bmap_nz;
logic ipsum_bmap_valid, ipsum_bmap_ready;
logic [`SPARSE_BLOCK_SIZE-1:0] ipsum_bmap_data;
logic [`SPARSE_COUNT_BITS-1:0] ipsum_bmap_nz;
logic opsum_bmap_valid, opsum_bmap_ready;
logic [`SPARSE_BLOCK_SIZE-1:0] opsum_bmap_data;
logic [`SPARSE_COUNT_BITS-1:0] opsum_bmap_nz;
logic opsum_bmap_capture_busy;
logic opsum_bmap_capture_done;

logic [`SPARSE_BLOCK_SIZE-1:0] ifmap_bmap_rd_data;
logic [`SPARSE_COUNT_BITS-1:0] ifmap_bmap_rd_nz;
logic [`SPARSE_BLOCK_SIZE-1:0] filter_bmap_rd_data;
logic [`SPARSE_COUNT_BITS-1:0] filter_bmap_rd_nz;
logic [`SPARSE_BLOCK_SIZE-1:0] ipsum_bmap_rd_data;
logic [`SPARSE_COUNT_BITS-1:0] ipsum_bmap_rd_nz;
logic [`SPARSE_BLOCK_SIZE-1:0] opsum_bmap_rd_data;
logic [`SPARSE_COUNT_BITS-1:0] opsum_bmap_rd_nz;

logic opsum_dense_fire;
logic opsum_store_sparse;
logic opsum_store_nonzero;
logic opsum_bmap_flush;
logic opsum_bmap_flush_sent;

logic [`GLB_ADDR_BITS-1:0] ifmap_len_mem [0:`SPARSE_BMAP_DEPTH-1];
logic [`GLB_ADDR_BITS-1:0] filter_len_mem [0:`SPARSE_BMAP_DEPTH-1];
logic [`GLB_ADDR_BITS-1:0] ofmap_len_mem [0:`SPARSE_BMAP_DEPTH-1];
logic [`SPARSE_BMAP_ADDR_BITS-1:0] ifmap_len_ptr;
logic [`SPARSE_BMAP_ADDR_BITS-1:0] filter_len_ptr;
logic [`SPARSE_BMAP_ADDR_BITS-1:0] ofmap_len_ptr;
logic [`AXI_ADDR_BITS-1:0] ifmap_dma_word_offset;
logic [`AXI_ADDR_BITS-1:0] filter_dma_word_offset;
logic [`AXI_ADDR_BITS-1:0] ofmap_dma_word_offset;
logic [`GLB_ADDR_BITS-3:0] ifmap_glb_word_offset;
logic [`GLB_ADDR_BITS-3:0] filter_glb_word_offset;
logic [`GLB_ADDR_BITS-3:0] ofmap_glb_word_offset;
logic [`GLB_ADDR_BITS-1:0] sparse_dma_len;
logic sparse_dma_active;
logic sparse_dma_zero;
logic sparse_dma_done_fire;
logic filter_sparse_dma_done_fire;
logic ifmap_sparse_dma_done_fire;

PE_array #(
    .FULL_THROUGHPUT_GON(FULL_THROUGHPUT_GON),
    .GON_FIFO_DEPTH(GON_FIFO_DEPTH)
) PE_array(
    .clk(clk),
    .rst(rst),
    /* Scan Chain */
    .set_XID(set_XID),
    .ifmap_XID_scan_in(ifmap_XID_scan_in),
    .filter_XID_scan_in(filter_XID_scan_in),
    .ipsum_XID_scan_in(ipsum_XID_scan_in),
    .opsum_XID_scan_in(opsum_XID_scan_in),
    .set_YID(set_YID),
    .ifmap_YID_scan_in(ifmap_YID_scan_in),
    .filter_YID_scan_in(filter_YID_scan_in),
    .ipsum_YID_scan_in(ipsum_YID_scan_in),
    .opsum_YID_scan_in(opsum_YID_scan_in),
    .set_LN(set_LN),
    .LN_config_in(LN_config_in),

    /* Controller */
    .PE_en(PE_en),
    .PE_config(PE_config),
    .ifmap_tag_X(ifmap_tag_X),
    .ifmap_tag_Y(ifmap_tag_Y),
    .filter_tag_X(filter_tag_X),
    .filter_tag_Y(filter_tag_Y),
    .ipsum_tag_X(ipsum_tag_X),
    .ipsum_tag_Y(ipsum_tag_Y),
    .opsum_tag_X(opsum_tag_X),
    .opsum_tag_Y(opsum_tag_Y),
    .opsum_next_tag_X(opsum_next_tag_X),
    .opsum_next_tag_Y(opsum_next_tag_Y),
    .opsum_next_tag_valid(opsum_next_tag_valid),
    .GON_opsum_issue_valid(PEA_opsum_issue_valid),
    .GON_opsum_issue_ready(PEA_opsum_issue_ready),
    .GON_opsum_issue_fire(PEA_opsum_issue_fire),

    /* GLB */
    .GLB_ifmap_valid(PEA_ifmap_valid_array),
    .GLB_ifmap_ready(PEA_ifmap_ready_array),
    .GLB_filter_valid(PEA_filter_valid_array),
    .GLB_filter_ready(PEA_filter_ready_array),
    .GLB_ipsum_valid(PEA_ipsum_valid_array),
    .GLB_ipsum_ready(PEA_ipsum_ready_array),
    .GLB_data_in(GLB_data_in_sparse),

    .GLB_opsum_valid(PEA_opsum_valid),
    .GLB_opsum_ready(PEA_opsum_ready),
    .GLB_data_out(GLB_data_out_PEarray)
);

logic [7:0] ppu_data_out;
logic relu_sel, comp_en, comp_init;

PPU PPU (
    .clk(clk),
    .rst(rst),
    .data_in(GLB_DO),
    .scaling_factor(scaling_factor_i),
    .maxpool_en(comp_en),
    .maxpool_init(comp_init),
    .relu_sel(relu_sel),
    .relu_en(relu_i),
    .data_out(ppu_data_out)
);

always_ff @(posedge clk) begin
    if (rst) begin
        asic_en_q <= 1'b0;
        ctrl_DMA_en_q <= 1'b0;
        ctrl_DMA_mode_q <= 2'd0;
        sparse_read_sel_q <= `SPARSE_READ_NONE;
    end
    else begin
        asic_en_q <= asic_en;
        ctrl_DMA_en_q <= ctrl_DMA_en;
        ctrl_DMA_mode_q <= ctrl_DMA_mode;
        sparse_read_sel_q <= sparse_read_sel;
    end
end
assign sparse_start = asic_en & ~asic_en_q;
assign filter_dma_group_start = ctrl_DMA_en && (ctrl_DMA_mode == `MODE_FILTER) &&
                                !(ctrl_DMA_en_q && (ctrl_DMA_mode_q == `MODE_FILTER));
assign filter_read_group_start = (sparse_read_sel == `SPARSE_READ_FILTER) &&
                                 (sparse_read_sel_q != `SPARSE_READ_FILTER);
assign ifmap_replay_start = ifmap_sparse_en_i && filter_read_group_start;

always_comb begin
    sparse_len_rd_data = '0;
    case (sparse_len_rd_sel)
        `SPARSE_SEL_IFMAP: sparse_len_rd_data = ifmap_len_mem[sparse_len_rd_addr];
        `SPARSE_SEL_FILTER: sparse_len_rd_data = filter_len_mem[sparse_len_rd_addr];
        `SPARSE_SEL_OPSUM: sparse_len_rd_data = ofmap_len_mem[sparse_len_rd_addr];
        default: sparse_len_rd_data = '0;
    endcase
end

always_ff @(posedge clk) begin
    if (sparse_len_wr_en) begin
        case (sparse_len_wr_sel)
            `SPARSE_SEL_IFMAP: ifmap_len_mem[sparse_len_wr_addr] <= sparse_len_wr_data;
            `SPARSE_SEL_FILTER: filter_len_mem[sparse_len_wr_addr] <= sparse_len_wr_data;
            `SPARSE_SEL_OPSUM: ofmap_len_mem[sparse_len_wr_addr] <= sparse_len_wr_data;
            default: begin end
        endcase
    end
end

always_comb begin
    sparse_dma_len = ctrl_DMA_len;
    case (ctrl_DMA_mode)
        `MODE_IFMAP: sparse_dma_len = ifmap_len_mem[ifmap_len_ptr];
        `MODE_FILTER: sparse_dma_len = filter_len_mem[filter_len_ptr];
        `MODE_OFMAP: sparse_dma_len = ofmap_len_mem[ofmap_len_ptr];
        default: sparse_dma_len = ctrl_DMA_len;
    endcase
end

assign sparse_dma_active = ctrl_DMA_en &&
                           ((ctrl_DMA_mode == `MODE_FILTER) ||
                            (ifmap_sparse_en_i && (ctrl_DMA_mode == `MODE_IFMAP)));
assign sparse_dma_zero = sparse_dma_active && (sparse_dma_len == '0);
assign ctrl_DMA_done = DMA_done || sparse_dma_zero;
assign sparse_dma_done_fire = ctrl_DMA_en && ctrl_DMA_done && sparse_dma_active;
assign filter_sparse_dma_done_fire = sparse_dma_done_fire &&
                                     (ctrl_DMA_mode == `MODE_FILTER);
assign ifmap_sparse_dma_done_fire = sparse_dma_done_fire &&
                                    (ctrl_DMA_mode == `MODE_IFMAP);

always_ff @(posedge clk) begin
    if (rst || sparse_start) begin
        ifmap_len_ptr <= '0;
        filter_len_ptr <= '0;
        ofmap_len_ptr <= '0;
        ifmap_dma_word_offset <= '0;
        filter_dma_word_offset <= '0;
        ofmap_dma_word_offset <= '0;
        ifmap_glb_word_offset <= '0;
        filter_glb_word_offset <= '0;
        ofmap_glb_word_offset <= '0;
    end
    else begin
        if (filter_dma_group_start) filter_glb_word_offset <= '0;

        if (sparse_dma_done_fire) begin
            case (ctrl_DMA_mode)
                `MODE_IFMAP: begin
                    ifmap_len_ptr <= ifmap_len_ptr + 1'b1;
                    ifmap_dma_word_offset <= ifmap_dma_word_offset + {{(`AXI_ADDR_BITS-`GLB_ADDR_BITS){1'b0}}, sparse_dma_len};
                    ifmap_glb_word_offset <= '0;
                end
                `MODE_FILTER: begin
                    filter_len_ptr <= filter_len_ptr + 1'b1;
                    filter_dma_word_offset <= filter_dma_word_offset + {{(`AXI_ADDR_BITS-`GLB_ADDR_BITS){1'b0}}, sparse_dma_len};
                    filter_glb_word_offset <=
                        (filter_dma_group_start ? '0 : filter_glb_word_offset) +
                        sparse_dma_len[`GLB_ADDR_BITS-3:0];
                end
                `MODE_OFMAP: begin
                    ofmap_len_ptr <= ofmap_len_ptr + 1'b1;
                    ofmap_dma_word_offset <= ofmap_dma_word_offset + {{(`AXI_ADDR_BITS-`GLB_ADDR_BITS){1'b0}}, sparse_dma_len};
                    ofmap_glb_word_offset <= ofmap_glb_word_offset + sparse_dma_len[`GLB_ADDR_BITS-3:0];
                end
                default: begin end
            endcase
        end
    end
end

BitmapBuffer #(
    .BLOCK_SIZE(`SPARSE_BLOCK_SIZE),
    .DEPTH(`SPARSE_BMAP_DEPTH),
    .ADDR_W(`SPARSE_BMAP_ADDR_BITS),
    .COUNT_W(`SPARSE_COUNT_BITS)
) ifmap_bitmap_buffer (
    .clk(clk),
    .rst(rst),
    .host_wr_en(sparse_bitmap_wr_en && (sparse_bitmap_wr_sel == `SPARSE_SEL_IFMAP)),
    .host_wr_addr(sparse_bitmap_wr_addr),
    .host_bitmap_wdata(sparse_bitmap_wr_data),
    .host_nz_count_wdata(sparse_bitmap_wr_nz_count),
    .host_rd_en(1'b1),
    .host_rd_addr(sparse_bitmap_rd_addr),
    .host_bitmap_rdata(ifmap_bmap_rd_data),
    .host_nz_count_rdata(ifmap_bmap_rd_nz),
    .start_capture(1'b0),
    .capture_base(`SPARSE_BMAP_ADDR_BITS'd0),
    .capture_len({(`SPARSE_BMAP_ADDR_BITS+1){1'b0}}),
    .capture_busy(),
    .capture_done(),
    .enc_bitmap_i(`SPARSE_BLOCK_SIZE'd0),
    .enc_nz_count_i(`SPARSE_COUNT_BITS'd0),
    .enc_valid_i(1'b0),
    .enc_ready_o(),
    .start_stream(sparse_start || ifmap_replay_start),
    .stream_base(`SPARSE_BMAP_ADDR_BITS'd0),
    .stream_len({1'b1, {`SPARSE_BMAP_ADDR_BITS{1'b0}}}),
    .stream_busy(),
    .stream_done(),
    .dec_bitmap_o(ifmap_bmap_data),
    .dec_nz_count_o(ifmap_bmap_nz),
    .dec_valid_o(ifmap_bmap_valid),
    .dec_ready_i(ifmap_bmap_ready)
);

BitmapBuffer #(
    .BLOCK_SIZE(`SPARSE_BLOCK_SIZE),
    .DEPTH(`SPARSE_BMAP_DEPTH),
    .ADDR_W(`SPARSE_BMAP_ADDR_BITS),
    .COUNT_W(`SPARSE_COUNT_BITS)
) filter_bitmap_buffer (
    .clk(clk),
    .rst(rst),
    .host_wr_en(sparse_bitmap_wr_en && (sparse_bitmap_wr_sel == `SPARSE_SEL_FILTER)),
    .host_wr_addr(sparse_bitmap_wr_addr),
    .host_bitmap_wdata(sparse_bitmap_wr_data),
    .host_nz_count_wdata(sparse_bitmap_wr_nz_count),
    .host_rd_en(1'b1),
    .host_rd_addr(sparse_bitmap_rd_addr),
    .host_bitmap_rdata(filter_bmap_rd_data),
    .host_nz_count_rdata(filter_bmap_rd_nz),
    .start_capture(1'b0),
    .capture_base(`SPARSE_BMAP_ADDR_BITS'd0),
    .capture_len({(`SPARSE_BMAP_ADDR_BITS+1){1'b0}}),
    .capture_busy(),
    .capture_done(),
    .enc_bitmap_i(`SPARSE_BLOCK_SIZE'd0),
    .enc_nz_count_i(`SPARSE_COUNT_BITS'd0),
    .enc_valid_i(1'b0),
    .enc_ready_o(),
    .start_stream(sparse_start),
    .stream_base(`SPARSE_BMAP_ADDR_BITS'd0),
    .stream_len({1'b1, {`SPARSE_BMAP_ADDR_BITS{1'b0}}}),
    .stream_busy(),
    .stream_done(),
    .dec_bitmap_o(filter_bmap_data),
    .dec_nz_count_o(filter_bmap_nz),
    .dec_valid_o(filter_bmap_valid),
    .dec_ready_i(filter_bmap_ready)
);

BitmapBuffer #(
    .BLOCK_SIZE(`SPARSE_BLOCK_SIZE),
    .DEPTH(`SPARSE_BMAP_DEPTH),
    .ADDR_W(`SPARSE_BMAP_ADDR_BITS),
    .COUNT_W(`SPARSE_COUNT_BITS)
) ipsum_bitmap_buffer (
    .clk(clk),
    .rst(rst),
    .host_wr_en(sparse_bitmap_wr_en && (sparse_bitmap_wr_sel == `SPARSE_SEL_IPSUM)),
    .host_wr_addr(sparse_bitmap_wr_addr),
    .host_bitmap_wdata(sparse_bitmap_wr_data),
    .host_nz_count_wdata(sparse_bitmap_wr_nz_count),
    .host_rd_en(1'b1),
    .host_rd_addr(sparse_bitmap_rd_addr),
    .host_bitmap_rdata(ipsum_bmap_rd_data),
    .host_nz_count_rdata(ipsum_bmap_rd_nz),
    .start_capture(1'b0),
    .capture_base(`SPARSE_BMAP_ADDR_BITS'd0),
    .capture_len({(`SPARSE_BMAP_ADDR_BITS+1){1'b0}}),
    .capture_busy(),
    .capture_done(),
    .enc_bitmap_i(`SPARSE_BLOCK_SIZE'd0),
    .enc_nz_count_i(`SPARSE_COUNT_BITS'd0),
    .enc_valid_i(1'b0),
    .enc_ready_o(),
    .start_stream(sparse_start),
    .stream_base(`SPARSE_BMAP_ADDR_BITS'd0),
    .stream_len({1'b1, {`SPARSE_BMAP_ADDR_BITS{1'b0}}}),
    .stream_busy(),
    .stream_done(),
    .dec_bitmap_o(),
    .dec_nz_count_o(),
    .dec_valid_o(),
    .dec_ready_i(1'b0)
);

BitmapBuffer #(
    .BLOCK_SIZE(`SPARSE_BLOCK_SIZE),
    .DEPTH(`SPARSE_BMAP_DEPTH),
    .ADDR_W(`SPARSE_BMAP_ADDR_BITS),
    .COUNT_W(`SPARSE_COUNT_BITS)
) opsum_bitmap_buffer (
    .clk(clk),
    .rst(rst),
    .host_wr_en(sparse_bitmap_wr_en && (sparse_bitmap_wr_sel == `SPARSE_SEL_OPSUM)),
    .host_wr_addr(sparse_bitmap_wr_addr),
    .host_bitmap_wdata(sparse_bitmap_wr_data),
    .host_nz_count_wdata(sparse_bitmap_wr_nz_count),
    .host_rd_en(1'b1),
    .host_rd_addr(sparse_bitmap_rd_addr),
    .host_bitmap_rdata(opsum_bmap_rd_data),
    .host_nz_count_rdata(opsum_bmap_rd_nz),
    .start_capture(sparse_start),
    .capture_base(`SPARSE_BMAP_ADDR_BITS'd0),
    .capture_len({1'b1, {`SPARSE_BMAP_ADDR_BITS{1'b0}}}),
    .capture_busy(opsum_bmap_capture_busy),
    .capture_done(opsum_bmap_capture_done),
    .enc_bitmap_i(opsum_bmap_data),
    .enc_nz_count_i(opsum_bmap_nz),
    .enc_valid_i(opsum_bmap_valid),
    .enc_ready_o(opsum_bmap_ready),
    .start_stream(sparse_start),
    .stream_base(`SPARSE_BMAP_ADDR_BITS'd0),
    .stream_len({1'b1, {`SPARSE_BMAP_ADDR_BITS{1'b0}}}),
    .stream_busy(),
    .stream_done(),
    .dec_bitmap_o(ipsum_bmap_data),
    .dec_nz_count_o(ipsum_bmap_nz),
    .dec_valid_o(ipsum_bmap_valid),
    .dec_ready_i(ipsum_bmap_ready)
);

always_comb begin
    sparse_bitmap_rd_data = '0;
    sparse_bitmap_rd_nz_count = '0;
    case (sparse_bitmap_rd_sel)
        `SPARSE_SEL_IFMAP: begin
            sparse_bitmap_rd_data = ifmap_bmap_rd_data;
            sparse_bitmap_rd_nz_count = ifmap_bmap_rd_nz;
        end
        `SPARSE_SEL_FILTER: begin
            sparse_bitmap_rd_data = filter_bmap_rd_data;
            sparse_bitmap_rd_nz_count = filter_bmap_rd_nz;
        end
        `SPARSE_SEL_IPSUM: begin
            sparse_bitmap_rd_data = ipsum_bmap_rd_data;
            sparse_bitmap_rd_nz_count = ipsum_bmap_rd_nz;
        end
        `SPARSE_SEL_OPSUM: begin
            sparse_bitmap_rd_data = opsum_bmap_rd_data;
            sparse_bitmap_rd_nz_count = opsum_bmap_rd_nz;
        end
    endcase
end

assign sparse_ifmap_bit = ifmap_bmap_data[ifmap_bit_idx];
assign sparse_filter_bit = filter_bmap_data[filter_bit_idx];
assign sparse_ipsum_bit = ipsum_bmap_data[ipsum_bit_idx];
assign sparse_selected_pad = (sparse_read_sel == `SPARSE_READ_IFMAP) && (GLB_DO_select == `WITH_PAD);
assign ifmap_bitmap_valid = ifmap_bmap_valid;
assign ifmap_bitmap_ready = ifmap_bmap_ready;
assign ifmap_cmp_valid = (sparse_read_sel == `SPARSE_READ_IFMAP) &&
                         sparse_selected_valid && sparse_selected_nonzero;
assign ifmap_cmp_ready = PEA_ifmap_ready;
assign ifmap_decoded_data = sparse_selected_nonzero ? GLB_DO : '0;
assign ifmap_is_padding = sparse_selected_pad;
assign ifmap_to_pe = GLB_data_in_sparse;

always_comb begin
    sparse_selected_nonzero = 1'b0;
    sparse_selected_valid = 1'b1;
    case (sparse_read_sel)
        `SPARSE_READ_IFMAP: begin
            sparse_selected_nonzero = sparse_selected_pad ? 1'b0 : sparse_ifmap_bit;
            sparse_selected_valid = sparse_selected_pad ? 1'b1 : ifmap_bmap_valid;
        end
        `SPARSE_READ_FILTER: begin
            sparse_selected_nonzero = sparse_filter_bit;
            sparse_selected_valid = filter_bmap_valid;
        end
        `SPARSE_READ_IPSUM: begin
            sparse_selected_nonzero = sparse_ipsum_bit;
            sparse_selected_valid = ipsum_bmap_valid;
        end
        default: begin
            sparse_selected_nonzero = 1'b1;
            sparse_selected_valid = 1'b1;
        end
    endcase
end

assign PEA_ifmap_valid_array = PEA_ifmap_valid && sparse_selected_valid;
assign PEA_filter_valid_array = PEA_filter_valid && sparse_selected_valid;
assign PEA_ipsum_valid_array = PEA_ipsum_valid && sparse_selected_valid;
assign PEA_ifmap_ready = PEA_ifmap_ready_array && sparse_selected_valid;
assign PEA_filter_ready = PEA_filter_ready_array && sparse_selected_valid;
assign PEA_ipsum_ready = PEA_ipsum_ready_array && sparse_selected_valid;

assign sparse_selected_fire = (PEA_ifmap_valid && PEA_ifmap_ready) ||
                              (PEA_filter_valid && PEA_filter_ready) ||
                              (PEA_ipsum_valid && PEA_ipsum_ready);
assign sparse_selected_consumes_bitmap = sparse_selected_fire &&
                                         (sparse_read_sel != `SPARSE_READ_NONE) &&
                                         !sparse_selected_pad;
assign ifmap_bmap_ready = sparse_selected_consumes_bitmap &&
                          (sparse_read_sel == `SPARSE_READ_IFMAP) &&
                          (ifmap_bit_idx == (`SPARSE_BLOCK_SIZE-1));
assign filter_bmap_ready = sparse_selected_consumes_bitmap &&
                           (sparse_read_sel == `SPARSE_READ_FILTER) &&
                           (filter_bit_idx == (`SPARSE_BLOCK_SIZE-1));
assign ipsum_bmap_ready = sparse_selected_consumes_bitmap &&
                          (sparse_read_sel == `SPARSE_READ_IPSUM) &&
                          (ipsum_bit_idx == (`SPARSE_BLOCK_SIZE-1));

assign opsum_dense_fire = PEA_opsum_valid && PEA_opsum_ready;
assign opsum_store_sparse = 1'b0;
assign opsum_store_nonzero = opsum_store_sparse && opsum_dense_fire && (GLB_data_out_PEarray != '0);
assign opsum_bmap_flush = asic_interrupt && (opsum_bit_idx != '0) && !opsum_bmap_flush_sent;
assign opsum_bmap_valid = (opsum_dense_fire && (opsum_bit_idx == (`SPARSE_BLOCK_SIZE-1))) ||
                          opsum_bmap_flush;
assign opsum_bmap_data = opsum_bmap_flush ? opsum_bitmap_q :
                         (GLB_data_out_PEarray != '0) ?
                         (opsum_bitmap_q | ({{(`SPARSE_BLOCK_SIZE-1){1'b0}}, 1'b1} << opsum_bit_idx)) :
                         opsum_bitmap_q;
assign opsum_bmap_nz = opsum_bmap_flush ? opsum_nz_count_q :
                       (GLB_data_out_PEarray != '0) ? (opsum_nz_count_q + 1'b1) : opsum_nz_count_q;

always_ff @(posedge clk) begin
    if (rst || sparse_start) begin
        ifmap_cmp_ptr <= '0;
        filter_cmp_ptr <= GLB_filter_addr_i[`GLB_ADDR_BITS-1:2];
        ipsum_cmp_ptr <= GLB_opsum_addr_i[`GLB_ADDR_BITS-1:2];
        opsum_cmp_ptr <= GLB_opsum_addr_i[`GLB_ADDR_BITS-1:2];
        ifmap_bit_idx <= '0;
        filter_bit_idx <= '0;
        ipsum_bit_idx <= '0;
        opsum_bit_idx <= '0;
        opsum_bitmap_q <= '0;
        opsum_nz_count_q <= '0;
        opsum_bmap_flush_sent <= 1'b0;
    end
    else begin
        if (opsum_bmap_flush && opsum_bmap_ready) begin
            opsum_bmap_flush_sent <= 1'b1;
        end

        if (filter_sparse_dma_done_fire || filter_read_group_start) begin
            filter_cmp_ptr <= GLB_filter_addr_i[`GLB_ADDR_BITS-1:2];
        end
        if (ifmap_sparse_dma_done_fire || ifmap_replay_start) begin
            ifmap_cmp_ptr <= '0;
            ifmap_bit_idx <= '0;
        end
        if (!filter_sparse_dma_done_fire && !filter_read_group_start &&
            !ifmap_sparse_dma_done_fire && !ifmap_replay_start &&
            sparse_selected_consumes_bitmap) begin
            if (sparse_read_sel == `SPARSE_READ_IFMAP) begin
                if (sparse_selected_nonzero) ifmap_cmp_ptr <= ifmap_cmp_ptr + 1'b1;
                ifmap_bit_idx <= (ifmap_bit_idx == (`SPARSE_BLOCK_SIZE-1)) ? '0 : ifmap_bit_idx + 1'b1;
            end
            else if (sparse_read_sel == `SPARSE_READ_FILTER) begin
                if (sparse_selected_nonzero) filter_cmp_ptr <= filter_cmp_ptr + 1'b1;
                filter_bit_idx <= (filter_bit_idx == (`SPARSE_BLOCK_SIZE-1)) ? '0 : filter_bit_idx + 1'b1;
            end
            else if (sparse_read_sel == `SPARSE_READ_IPSUM) begin
                if (sparse_selected_nonzero) ipsum_cmp_ptr <= ipsum_cmp_ptr + 1'b1;
                ipsum_bit_idx <= (ipsum_bit_idx == (`SPARSE_BLOCK_SIZE-1)) ? '0 : ipsum_bit_idx + 1'b1;
            end
        end

        if (opsum_dense_fire) begin
            if (GLB_data_out_PEarray != '0) begin
                opsum_bitmap_q[opsum_bit_idx] <= 1'b1;
                opsum_nz_count_q <= opsum_nz_count_q + 1'b1;
                opsum_cmp_ptr <= opsum_cmp_ptr + 1'b1;
            end

            if (opsum_bit_idx == (`SPARSE_BLOCK_SIZE-1)) begin
                opsum_bit_idx <= '0;
                opsum_bitmap_q <= '0;
                opsum_nz_count_q <= '0;
            end
            else begin
                opsum_bit_idx <= opsum_bit_idx + 1'b1;
            end
        end
    end
end

always_comb begin
    DMA_en = ctrl_DMA_en && !sparse_dma_zero;
    DMA_mode = ctrl_DMA_mode;
    DMA_DRAM_ADDR = ctrl_DMA_DRAM_ADDR;
    DMA_GLB_ADDR = ctrl_DMA_GLB_ADDR;
    DMA_len = ctrl_DMA_len;
    DMA_byte_bias = ctrl_DMA_byte_bias;

    if (sparse_dma_active) begin
        DMA_len = sparse_dma_len;
        case (ctrl_DMA_mode)
            `MODE_IFMAP: begin
                DMA_mode = `MODE_BIAS;
                DMA_DRAM_ADDR = ifmap_addr_i + {ifmap_dma_word_offset[`AXI_ADDR_BITS-3:0], 2'd0};
                DMA_GLB_ADDR = '0;
                DMA_byte_bias = 2'd0;
            end
            `MODE_FILTER: begin
                DMA_mode = `MODE_BIAS;
                DMA_DRAM_ADDR = filter_addr_i + {filter_dma_word_offset[`AXI_ADDR_BITS-3:0], 2'd0};
                DMA_GLB_ADDR = GLB_filter_addr_i +
                               {(filter_dma_group_start ? '0 :
                                 filter_glb_word_offset), 2'd0};
                DMA_byte_bias = 2'd0;
            end
            `MODE_OFMAP: begin
                DMA_mode = `MODE_OFMAP;
                DMA_DRAM_ADDR = ofmap_addr_i + {ofmap_dma_word_offset[`AXI_ADDR_BITS-3:0], 2'd0};
                DMA_GLB_ADDR = GLB_opsum_addr_i + {ofmap_glb_word_offset, 2'd0};
                DMA_byte_bias = 2'd0;
            end
            default: begin end
        endcase
    end

    /* GLB DI mux */
    GLB_data_out_sparse = (GLB_DI_select == `GLB_DO_PSUM)?GLB_data_out_PEarray:{24'd0,ppu_data_out};
    GLB_DI = GLB_data_out_sparse;
    /* GLB DO mux */
    GLB_data_in_PEarray = (GLB_DO_select == `WITH_PAD)?32'h80808080:GLB_DO;
    GLB_data_in_sparse = (sparse_selected_pad) ? 32'h80808080 :
                         (sparse_read_sel == `SPARSE_READ_NONE) ? GLB_data_in_PEarray :
                         (sparse_selected_nonzero ? GLB_DO : '0);
    GLB_EN = ctrl_GLB_EN;
    GLB_WEB = ctrl_GLB_WEB;
    GLB_MODE = ctrl_GLB_MODE;
    GLB_A = ctrl_GLB_A;
    GLB_mux = ctrl_GLB_mux;

    if (sparse_read_sel != `SPARSE_READ_NONE) begin
        if (sparse_selected_pad || !sparse_selected_nonzero || !sparse_selected_valid) begin
            GLB_EN = 1'b1;
        end
        else begin
            case (sparse_read_sel)
                `SPARSE_READ_IFMAP: GLB_A = {ifmap_cmp_ptr, 2'd0};
                `SPARSE_READ_FILTER: GLB_A = {filter_cmp_ptr, 2'd0};
                `SPARSE_READ_IPSUM: GLB_A = {ipsum_cmp_ptr, 2'd0};
                default: GLB_A = ctrl_GLB_A;
            endcase
        end
    end
    else if (opsum_store_sparse) begin
        GLB_A = {opsum_cmp_ptr, 2'd0};
        if (!opsum_store_nonzero) begin
            GLB_EN = 1'b1;
            GLB_WEB = 1'b1;
        end
    end
end

/*******************************************
    ASIC controller
********************************************/

generate
if (FULL_THROUGHPUT_GON) begin : FT_CONTROLLER
    asic_controller_ft asic_controller_0(
        .clk(clk),
        .rst(rst),
        .asic_en(asic_en),
        .asic_done(asic_interrupt),
        /* MMIO */
        .ifmap_addr(ifmap_addr_i),
        .filter_addr(filter_addr_i),
        .bias_addr(bias_addr_i),
        .ofmap_addr(ofmap_addr_i),
        .GLB_filter_addr(GLB_filter_addr_i),
        .GLB_bias_addr(GLB_bias_addr_i),
        .GLB_opsum_addr(GLB_opsum_addr_i),
        /* Layer Info */
        .maxpool(maxpool_i),
        .ifmap_sparse_en(ifmap_sparse_en_i),
        /* mapping parameters */
        .m(m_i),
        .e(e_i),
        .p(p_i),
        .q(q_i),
        .r(r_i),
        .t(t_i),
        /* shape parameters */
        .C(C_i),
        .M(M_i),
        .W(W_i),
        .H(H_i),
        /* DMA */
        .DMA_en(ctrl_DMA_en),
        .DMA_mode(ctrl_DMA_mode),
        .DMA_DRAM_ADDR(ctrl_DMA_DRAM_ADDR),
        .DMA_GLB_ADDR(ctrl_DMA_GLB_ADDR),
        .DMA_len(ctrl_DMA_len),
        .DMA_byte_bias(ctrl_DMA_byte_bias),
        .DMA_done(ctrl_DMA_done),
        /* ID config */
        .set_XID(set_XID),
        .ifmap_XID_scan_in(ifmap_XID_scan_in),
        .filter_XID_scan_in(filter_XID_scan_in),
        .ipsum_XID_scan_in(ipsum_XID_scan_in),
        .opsum_XID_scan_in(opsum_XID_scan_in),
        .set_YID(set_YID),
        .ifmap_YID_scan_in(ifmap_YID_scan_in),
        .filter_YID_scan_in(filter_YID_scan_in),
        .ipsum_YID_scan_in(ipsum_YID_scan_in),
        .opsum_YID_scan_in(opsum_YID_scan_in),
        .set_LN(set_LN),
        .LN_config_in(LN_config_in),

        /* PE_Array */
        .PE_en(PE_en),
        .PE_config(PE_config),

        .PEA_ifmap_valid(PEA_ifmap_valid),
        .PEA_ifmap_ready(PEA_ifmap_ready),
        .ifmap_tag_X(ifmap_tag_X),
        .ifmap_tag_Y(ifmap_tag_Y),


        .PEA_filter_valid(PEA_filter_valid),
        .PEA_filter_ready(PEA_filter_ready),
        .filter_tag_X(filter_tag_X),
        .filter_tag_Y(filter_tag_Y),

        .PEA_ipsum_valid(PEA_ipsum_valid),
        .PEA_ipsum_ready(PEA_ipsum_ready),
        .ipsum_tag_X(ipsum_tag_X),
        .ipsum_tag_Y(ipsum_tag_Y),

        .PEA_opsum_valid(PEA_opsum_valid),
        .PEA_opsum_ready(PEA_opsum_ready),
        .PEA_opsum_issue_valid(PEA_opsum_issue_valid),
        .PEA_opsum_issue_ready(PEA_opsum_issue_ready),
        .PEA_opsum_issue_fire(PEA_opsum_issue_fire),
        .opsum_tag_X(opsum_tag_X),
        .opsum_tag_Y(opsum_tag_Y),
        .opsum_next_tag_X(opsum_next_tag_X),
        .opsum_next_tag_Y(opsum_next_tag_Y),
        .opsum_next_tag_valid(opsum_next_tag_valid),

        /* GLB */
        .GLB_EN(ctrl_GLB_EN),
        .GLB_WEB(ctrl_GLB_WEB),
        .GLB_MODE(ctrl_GLB_MODE),
        .GLB_A(ctrl_GLB_A),
        .GLB_mux(ctrl_GLB_mux),
        .GLB_DI_select(GLB_DI_select),
        .GLB_DO_select(GLB_DO_select),
        .sparse_read_sel(sparse_read_sel),

        /* PPU */
        .Maxpool_en(comp_en),
        .Maxpool_init(comp_init),
        .relu_sel(relu_sel)
    );
end
else begin : CONSERVATIVE_CONTROLLER
    assign opsum_next_tag_X = 'd0;
    assign opsum_next_tag_Y = 'd0;
    assign opsum_next_tag_valid = 1'b0;
    assign PEA_opsum_issue_valid = 1'b0;
    assign PEA_opsum_issue_ready = 1'b0;

    asic_controller asic_controller_0(
        .clk(clk),
        .rst(rst),
        .asic_en(asic_en),
        .asic_done(asic_interrupt),
    /* MMIO */
    .ifmap_addr(ifmap_addr_i),
    .filter_addr(filter_addr_i),
    .bias_addr(bias_addr_i),
    .ofmap_addr(ofmap_addr_i),
    .GLB_filter_addr(GLB_filter_addr_i),
    .GLB_bias_addr(GLB_bias_addr_i),
    .GLB_opsum_addr(GLB_opsum_addr_i),
    /* Layer Info */
    .maxpool(maxpool_i),
    .ifmap_sparse_en(ifmap_sparse_en_i),
    /* mapping parameters */
    .m(m_i),
    .e(e_i),
    .p(p_i),
    .q(q_i),
    .r(r_i),
    .t(t_i),
    /* shape parameters */
    .C(C_i),
    .M(M_i),
    .W(W_i),
    .H(H_i),
    /* DMA */
    .DMA_en(ctrl_DMA_en),
    .DMA_mode(ctrl_DMA_mode),
    .DMA_DRAM_ADDR(ctrl_DMA_DRAM_ADDR),
    .DMA_GLB_ADDR(ctrl_DMA_GLB_ADDR),
    .DMA_len(ctrl_DMA_len),
    .DMA_byte_bias(ctrl_DMA_byte_bias),
    .DMA_done(ctrl_DMA_done),
    /* ID config */
    .set_XID(set_XID),
    .ifmap_XID_scan_in(ifmap_XID_scan_in),
    .filter_XID_scan_in(filter_XID_scan_in),
    .ipsum_XID_scan_in(ipsum_XID_scan_in),
    .opsum_XID_scan_in(opsum_XID_scan_in),
    .set_YID(set_YID),
    .ifmap_YID_scan_in(ifmap_YID_scan_in),
    .filter_YID_scan_in(filter_YID_scan_in),
    .ipsum_YID_scan_in(ipsum_YID_scan_in),
    .opsum_YID_scan_in(opsum_YID_scan_in),
    .set_LN(set_LN),
    .LN_config_in(LN_config_in),

    /* PE_Array */
    .PE_en(PE_en),
    .PE_config(PE_config),

    .PEA_ifmap_valid(PEA_ifmap_valid),
    .PEA_ifmap_ready(PEA_ifmap_ready),
    .ifmap_tag_X(ifmap_tag_X),
    .ifmap_tag_Y(ifmap_tag_Y),


    .PEA_filter_valid(PEA_filter_valid),
    .PEA_filter_ready(PEA_filter_ready),
    .filter_tag_X(filter_tag_X),
    .filter_tag_Y(filter_tag_Y),

    .PEA_ipsum_valid(PEA_ipsum_valid),
    .PEA_ipsum_ready(PEA_ipsum_ready),
    .ipsum_tag_X(ipsum_tag_X),
    .ipsum_tag_Y(ipsum_tag_Y),

    .PEA_opsum_valid(PEA_opsum_valid),
    .PEA_opsum_ready(PEA_opsum_ready),
    .opsum_tag_X(opsum_tag_X),
    .opsum_tag_Y(opsum_tag_Y),

    /* GLB */
    .GLB_EN(ctrl_GLB_EN),
    .GLB_WEB(ctrl_GLB_WEB),
    .GLB_MODE(ctrl_GLB_MODE),
    .GLB_A(ctrl_GLB_A),
    .GLB_mux(ctrl_GLB_mux),
    .GLB_DI_select(GLB_DI_select),
    .GLB_DO_select(GLB_DO_select),
    .sparse_read_sel(sparse_read_sel),

    /* PPU */
        .Maxpool_en(comp_en),
        .Maxpool_init(comp_init),
        .relu_sel(relu_sel)
    );
end
endgenerate


endmodule
