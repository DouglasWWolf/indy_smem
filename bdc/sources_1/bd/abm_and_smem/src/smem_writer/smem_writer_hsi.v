/*
===============================================================================
                   ------->  Revision History  <------
===============================================================================

   Date    Who  Ver  Changes
===============================================================================
18-Feb-26  DWW    1  Initial creation
===============================================================================
*/


/*
     This module writes a chunk (i.e., 256 bytes) of data to SMEM via the
     HSI interface as a "command word" followed by a series of 64 32-bit data  
     words.  The "command word" is simply the {row, bank} where this chunk
     of data will be stored in SMEM.

     When the 'start' input strobes high, this module begins sending smem_data<N>
     to a FIFO, and on the other side of that FIFO is logic that clocks the data
     out the HSI bus, synhronous with the hsi_pclk.

     When this module is ready to accept more data (i.e., when it's ready for 
     someone to assert 'start'), the 'ready' signal is asserted.

     When this module is completely idle (i.e., all data has been clocked out 
     the HSI bus and has been written to SMEM), the 'done' signal is asserted.

     If the 'smem_wen' line is asserted at any point, the HSI bus pauses
     until 'smem_wen' is de-asserted.  


    To understand this module, it's useful to know that an ABM (Activation Bitmap)
    is a blob of data that is carved into 256 byte "chunks" of data. There is
    one 256 byte chunk for each combination of sensor-chip row and bank.  (There
    are 512 rows and 8 banks, for a total of 4096 chunks)

    One of the inputs to this module is "chunk_index".  A single chunk of incoming
    data is the aforementioned 256 bytes (i.e., 2048 bits). The "chunk_index" is simply
    a sequential integer that indicates which chunk (of the ABM) is being processed.
    The order of chunks of data in an ABM is:
           Row 0  : bank0, bank1, bank2, bank3, bank4, bank5, bank6, bank7
           Row 1  : bank0, bank1, bank2, bank3, bank4, bank5, bank6, bank7
           Row 2  : bank0, bank1, bank2, bank3, bank4, bank5, bank6, bank7
           (...)
           Row 511: bank0, bank1, bank2, bank3, bank4, bank5, bank6, bank7
    
    The SMEM row and bank can be derived from the "chunk_index" like this:
        Bank = chunk_index[ 2:0]
        Row  = chunk_index[11:3]

    It's worth noting that the order of chunks of data in sensor-chip SMEM is:
        Bank 0: row 0, row 1, row2, row3, [...], row 511
        Bank 1: row 0, row 1, row2, row3, [...], row 511
        Bank 2: row 0, row 1, row2, row3, [...], row 511
            (...)
        Bank 7: row 0, row 1, row2, row3, [...], row 511
*/


module smem_writer_hsi # (parameter HSI_IDLE_COUNT = 7)
(

    input           clk,
    input           resetn,

    // Individual 32-bit words in i_smem_data must be in little-endian
    // byte order!
    input  [2047:0] i_smem_data,  
    input  [  31:0] i_chunk_index,
    input           i_start,
    output          smem_write_stb,
    output          done,
    output          ready,

    // SMEM write-enable.  When this is low, SMEM updating is paused
    input           smem_wen, 

    //==================================================================
    // These registers should all be packed into IOBs on the FPGA
    //==================================================================
    output        chip_hsi_pclk,
    output [31:0] chip_hsi_data,
    output        chip_hsi_cmd,
    output        chip_hsi_eop,
    output        chip_hsi_valid
    //==================================================================

);


//--------------------------------------------------------
// These connect smem_writer_s1 to the FIFO
//--------------------------------------------------------
wire[31:0] s_axis_tdata;
wire       s_axis_tlast;
wire       s_axis_tuser;
wire       s_axis_tvalid;
wire       s_axis_tready;
//--------------------------------------------------------


//--------------------------------------------------------
// These connect the FIFO to smem_writer_s2
//--------------------------------------------------------
wire[31:0] m_axis_tdata;
wire       m_axis_tlast;
wire       m_axis_tuser;
wire       m_axis_tvalid;
wire       m_axis_tready;
//--------------------------------------------------------


//--------------------------------------------------------
// Other signals that move between stage 1 and stage 2
//--------------------------------------------------------
wire fifo_empty;
//--------------------------------------------------------


//--------------------------------------------------------
// HSI based SMEM writer - stage 1 (before the FIFO)
//--------------------------------------------------------
smem_writer_hsi_s1 i_smem_writer_hsi_s1
(
    .clk                (clk),
    .resetn             (resetn),
    .i_smem_data        (i_smem_data),
    .i_chunk_index      (i_chunk_index),
    .i_start            (i_start),
    .smem_write_stb     (smem_write_stb),
    .done               (done),
    .ready              (ready),
    .axis_out_tdata     (s_axis_tdata),
    .axis_out_tlast     (s_axis_tlast),
    .axis_out_tuser     (s_axis_tuser),
    .axis_out_tvalid    (s_axis_tvalid),
    .axis_out_tready    (s_axis_tready),
    .fifo_empty         (fifo_empty)
);
//--------------------------------------------------------



//--------------------------------------------------------
// HSI based SMEM writer - stage 2 (after the FIFO)
//--------------------------------------------------------
smem_writer_hsi_s2 # (.HSI_IDLE_COUNT(HSI_IDLE_COUNT)) i_smem_writer_hsi_s2 
(
    .clk            (clk),
    .fifo_empty     (fifo_empty),
    .smem_wen       (smem_wen),
    .axis_in_tdata  (m_axis_tdata),
    .axis_in_tlast  (m_axis_tlast),
    .axis_in_tuser  (m_axis_tuser),
    .axis_in_tvalid (m_axis_tvalid),
    .axis_in_tready (m_axis_tready),
    .chip_hsi_pclk  (chip_hsi_pclk),
    .chip_hsi_data  (chip_hsi_data),
    .chip_hsi_cmd   (chip_hsi_cmd),
    .chip_hsi_eop   (chip_hsi_eop),
    .chip_hsi_valid (chip_hsi_valid)
);
//--------------------------------------------------------


//=============================================================================
// TLAST is asserted on the last element of an SMEM chunk
// TUSER is asserted on the HSI command word that precedes the SMEM chunk data
//=============================================================================
xpm_fifo_axis #
(
   .FIFO_DEPTH      (16),
   .TDATA_WIDTH     (32),
   .TUSER_WIDTH     ( 1),
   .FIFO_MEMORY_TYPE("auto"),
   .PACKET_FIFO     ("false"),
   .USE_ADV_FEATURES("0000"),
   .CDC_SYNC_STAGES (3),
   .CLOCKING_MODE   ("common_clock")
)
hsi_fifo
(
    // Clock and reset
   .s_aclk   (clk    ),
   .m_aclk   (clk    ),
   .s_aresetn(resetn ),

    // This input bus of the FIFO
   .s_axis_tdata (s_axis_tdata ),
   .s_axis_tuser (s_axis_tuser ),
   .s_axis_tlast (s_axis_tlast ),
   .s_axis_tvalid(s_axis_tvalid),
   .s_axis_tready(s_axis_tready),

    // The output bus of the FIFO
   .m_axis_tdata (m_axis_tdata ),
   .m_axis_tuser (m_axis_tuser ),
   .m_axis_tlast (m_axis_tlast ),
   .m_axis_tvalid(m_axis_tvalid),
   .m_axis_tready(m_axis_tready),

    // Unused input stream signals
   .s_axis_tdest(),
   .s_axis_tid  (),
   .s_axis_tstrb(),
   .s_axis_tkeep(),

    // Unused output stream signals
   .m_axis_tdest(),
   .m_axis_tid  (),
   .m_axis_tstrb(),
   .m_axis_tkeep(),

    // Other unused signals
   .almost_empty_axis(),
   .almost_full_axis(),
   .dbiterr_axis(),
   .prog_empty_axis(),
   .prog_full_axis(),
   .rd_data_count_axis(),
   .sbiterr_axis(),
   .wr_data_count_axis(),
   .injectdbiterr_axis(),
   .injectsbiterr_axis()
);
//====================================================================================


endmodule