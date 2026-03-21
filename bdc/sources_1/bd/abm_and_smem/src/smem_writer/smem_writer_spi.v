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
    This module writes data to SMEM, one 32-bit word at a time, over the chip_spi
    interface.

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


// `define DEBUG_PORTS
module smem_writer_spi # (SIM_SPI = 0)
(
    
    `ifdef DEBUG_PORTS
        output[31:0] dbg_fifo_in_tdata,
        output[31:0] dbg_fifo_in_tuser,
        output       dbg_fifo_in_tvalid,
        output       dbg_fifo_in_tready,

        output[31:0] dbg_fifo_out_tdata,
        output[31:0] dbg_fifo_out_tuser,
        output       dbg_fifo_out_tvalid,
        output       dbg_fifo_out_tready,
    `endif

    (* X_INTERFACE_INFO      = "xilinx.com:signal:clock:1.0 clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_RESET resetn, ASSOCIATED_BUSIF dbg_fifo_in:dbg_fifo_out" *)
    input       clk,
    input       resetn,

    // When start strobes high, this holds 1 chunk of data to write to SMEM.
    // The individual 32-bit words in this field must be in little-endian 
    // byte order    
    input[2047:0] i_smem_data,
    
    // When start strobes high, this is the chunk-index in the ABM
    input[31:0] i_chunk_index,

    // When start strobes high, this is a bitmap of which of the 64 words of
    // data should be written to SMEM
    input[63:0] i_mismatch_bitmap,

    // When this goes high, we will start pushing data to the output stream
    input       i_start,
    
    // This is high when we're ready for someone to tell us to start
    output      ready,

    // This is asserted when all available data has been flushed to the SMEM
    // on the sensor chip
    output      done,

    // Interface to the SPI bus
    output reg [31:0] spi_addr,
    output reg [31:0] spi_wdata,
    output reg [ 1:0] spi_start,
    input             spi_busy,

    // SMEM write-enable : when this is low, SMEM updating is paused
    input            smem_wen,
    
    // Strobes high for one data-cycle every time we write a word to SMEM
    output           smem_write_stb
);

genvar i;

// The "smem_data" field is 2048 bits wide: 1 chunk of data for one bank/row
localparam DW = 2048;

// Number of 32-bit words that will fit into smem_data
localparam WORDS_PER_CHUNK = DW / 32;

// For a 2048 bit chunk, there are 64 words per chunk, numbered 0 thru 63
localparam LAST_WORD = WORDS_PER_CHUNK - 1;

// We strobe this command to spi_start to begin an SMEM write.
// 2 = Perform an ordinary write to SMEM over SPI
// 3 = Simulate a very rapid write to SMEM (for debugging)
localparam SPI_START_WRITE = (SIM_SPI) ? 3: 2;

// The base address of SMEM on the sensor-chip
localparam SMEM_BASE_ADDR = 32'h8000;

//----------------------------------------------------------
// This feeds a FIFO
//----------------------------------------------------------
wire[31:0] fifo_in_tdata;
wire[31:0] fifo_in_tuser;
wire       fifo_in_tvalid;
wire       fifo_in_tready;

//---------------------------------------------------------
// This is asserted by the SPI driver logic
//---------------------------------------------------------
wire fifo_empty;
//----------------------------------------------------------

// Our 256 bytes of smem_data contain a total of 64 32-bit words.
// This value will increment from 0 to 63
reg[5:0] word_number;

//-----------------------------------------------------------------------------
// These are registered versions of the corresponding input ports
//-----------------------------------------------------------------------------
reg[63:0] mismatch_bitmap;
reg[31:0] element[0:WORDS_PER_CHUNK-1];
reg       start;
reg[ 2:0] bank;
reg[ 8:0] row;
//-----------------------------------------------------------------------------


//=============================================================================
// Register the input fields to make timing closure simpler
//=============================================================================
always @(posedge clk) begin
    if (resetn == 0)
        start <= 0;
    else begin
        start           <= i_start;
        bank            <= i_chunk_index[ 2:0];
        row             <= i_chunk_index[11:3];
        mismatch_bitmap <= i_mismatch_bitmap;
    end
end
//=============================================================================


//=============================================================================
// This registers "smem_data" into an array of 64 32-bit words
//=============================================================================
for (i=0; i<WORDS_PER_CHUNK; i=i+1) begin
    always @(posedge clk) element[i] <= i_smem_data[i*32 +: 32];
end
//=============================================================================


//=============================================================================
// This state machine waits for someone to tell us to start, then stuffs a
// 32-bit SMEM value (and SMEM address) into the FIFO for any word in the chunk
// that requires updating in SMEM.
//=============================================================================

// A shift register that holds the mismatch-bitmap
reg[63:0] mismatch_sr;

// Holds the current SMEM address
reg[31:0] smem_address;

// The state of this state machine
reg fsm_state;
//-----------------------------------------------------------------------------
always @(posedge clk) begin
    if (resetn == 0) begin
        fsm_state <= 0;
    end

    else case(fsm_state)

        // Wait for someone to tell us to start.  Note that when we compute
        // the smem_address here, "chunks" of data in SMEM are in a different
        // row/bank order than the incoming data is!
        0:  if (start) begin
                mismatch_sr  <= mismatch_bitmap;
                word_number  <= 0;
                smem_address <= SMEM_BASE_ADDR + {bank, row, 8'b0};
                fsm_state    <= 1;
            end
        
        // Wait for each entry to be either ignored (because it's not a mismatch)
        // or accepted into the FIFO (because it's a mismatch)
        1:  if ((mismatch_sr[0] == 0) | (fifo_in_tvalid & fifo_in_tready)) begin
                if (word_number != LAST_WORD) begin
                    mismatch_sr  <= (mismatch_sr >> 1);
                    word_number  <= word_number + 1;
                    smem_address <= smem_address + 4;
                end else
                    fsm_state <= 0;
            end

    endcase

end

assign fifo_in_tdata  = element[word_number];
assign fifo_in_tuser  = smem_address;
assign fifo_in_tvalid = (resetn == 1) & (fsm_state == 1) & (mismatch_sr[0]);

// Strobe this high for one clock cycle every time we write a word of data 
// into the FIFO.  This is used by other modules to count the number 
// of words that get written to SMEM
assign smem_write_stb = (fsm_state == 1) & fifo_in_tvalid & fifo_in_tready;
//=============================================================================


// We're ready to accept another chunk of data when the state machine is idle
assign ready = (fsm_state == 0) & (start == 0) & (i_start == 0);

// All chunks have been written to SMEM when this is asserted
assign done = (ready & fifo_empty);

//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
//             From here down is the output side of the FIFO
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

// This is the output side of the FIFO
wire[31:0] fifo_out_tdata;
wire[31:0] fifo_out_tuser;
wire       fifo_out_tvalid;
wire       fifo_out_tready;


//=============================================================================
// This state machine reads entries (an entry is a 32-bit SMEM address and 
// 32-bits of data) and sends them off to the chip_spi to perform the 
// transaction.
//=============================================================================
reg spi_state;
//-----------------------------------------------------------------------------
always @(posedge clk) begin

    // This strobes high for a single cycle
    spi_start <= 0;

    // When we're in reset, initialize important registers
    if (resetn == 0) begin
        spi_state <= 0;
    end

    else case(spi_state)

        // Wait for an entry from the FIFO.  When one arrive,
        // start a chip_spi transaction
        0:  if (fifo_out_tvalid & fifo_out_tready) begin
                spi_addr  <= fifo_out_tuser;
                spi_wdata <= fifo_out_tdata;
                spi_start <= SPI_START_WRITE;
                spi_state <= 1;
            end

        // Here we wait for the chip_spi transaction to complete
        1:  if (!spi_busy) spi_state <= 0;

    endcase

end

// We're ready to accept an entry from the FIFO under these conditions
assign fifo_out_tready = (resetn == 1) & (spi_state == 0) & smem_wen;

// This is asserted when there is no data available to read from the FIFO
assign fifo_empty = (resetn == 1) & (spi_state == 0) & (fifo_out_tvalid == 0);
//=============================================================================



//=============================================================================
// This FIFO carries data to write to SMEM and the address to write it to
//=============================================================================
xpm_fifo_axis #
(
   .FIFO_DEPTH      (16),
   .TDATA_WIDTH     (32),
   .TUSER_WIDTH     (32),
   .FIFO_MEMORY_TYPE("auto"),
   .PACKET_FIFO     ("false"),
   .USE_ADV_FEATURES("0000"),
   .CDC_SYNC_STAGES (3),
   .CLOCKING_MODE   ("common_clock")
)
spi_fifo
(
    // Clock and reset
   .s_aclk   (clk    ),
   .m_aclk   (clk    ),
   .s_aresetn(resetn ),

    // This input bus of the FIFO
   .s_axis_tdata (fifo_in_tdata ), 
   .s_axis_tuser (fifo_in_tuser ),
   .s_axis_tvalid(fifo_in_tvalid),
   .s_axis_tready(fifo_in_tready),

    // The output bus of the FIFO
   .m_axis_tdata (fifo_out_tdata ),
   .m_axis_tuser (fifo_out_tuser ),
   .m_axis_tvalid(fifo_out_tvalid),
   .m_axis_tready(fifo_out_tready),

    // Unused input stream signals
   .s_axis_tlast(),
   .s_axis_tdest(),
   .s_axis_tid  (),
   .s_axis_tstrb(),
   .s_axis_tkeep(),

    // Unused output stream signals
   .m_axis_tlast(),
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


`ifdef DEBUG_PORTS
    assign  dbg_fifo_in_tdata   = fifo_in_tdata  ; 
    assign  dbg_fifo_in_tuser   = fifo_in_tuser  ;  
    assign  dbg_fifo_in_tvalid  = fifo_in_tvalid ;
    assign  dbg_fifo_in_tready  = fifo_in_tready ;

    assign  dbg_fifo_out_tdata  = fifo_out_tdata ; 
    assign  dbg_fifo_out_tuser  = fifo_out_tuser ;  
    assign  dbg_fifo_out_tvalid = fifo_out_tvalid;
    assign  dbg_fifo_out_tready = fifo_out_tready;
`endif



endmodule