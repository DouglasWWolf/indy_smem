`timescale 1 ps / 1 ps

module project_top
(
                        output [4:0]    CHIP_GPIO,
                        output          CHIP_HSI_CLK,
                        output          CHIP_HSI_CMD,
                        output [31:0]   CHIP_HSI_DATA,
                        output          CHIP_HSI_VALID,
                        output          CHIP_RESET_N,
                        output          CHIP_SPI_CLK,
                        output          CHIP_SPI_CSN,
                        input           CHIP_SPI_MISO,
                        output          CHIP_SPI_MOSI,
                        output          CHIP_VDD,
                        output          CHIP_VDDA,
                        output          CHIP_VDDIO,
                        output          CHIP_VDDLVDS,
                        output          LVL_TRSL_OE_N,
                        output [2:0]    UCI_ADC_CSN,
                        input           UCI_ADC_MISO,
                        output          UCI_ADC_MOSI,
                        output          UCI_ADC_SCK,
                        input  [15:0]   pcie_mgt_rxn,
                        input  [15:0]   pcie_mgt_rxp,
                        output [15:0]   pcie_mgt_txn,
                        output [15:0]   pcie_mgt_txp,
                        input           pcie_refclk_clk_n,
                        input           pcie_refclk_clk_p,
                        input           qsfp0_clk_clk_n,
                        input           qsfp0_clk_clk_p,
                        input  [3:0]    qsfp0_gt_grx_n,
                        input  [3:0]    qsfp0_gt_grx_p,
                        output [3:0]    qsfp0_gt_gtx_n,
                        output [3:0]    qsfp0_gt_gtx_p,
                        input           qsfp1_clk_clk_n,
                        input           qsfp1_clk_clk_p,
                        input  [3:0]    qsfp1_gt_grx_n,
                        input  [3:0]    qsfp1_gt_grx_p,
                        output [3:0]    qsfp1_gt_gtx_n,
                        output [3:0]    qsfp1_gt_gtx_p,
                        output          qsfp0_up,
                        output          qsfp1_up,
                        output [1:0]    qsfp_lp,
                        output [1:0]    qsfp_rst_l
);

// QSFP active-low reset lines
assign qsfp_rst_l = -1;

// QSFP low-power mode ( 1 =  turn off the amplifiers)
assign qsfp_lp = 0;

// This probably isn't neccessary
assign CHIP_GPIO = 2;

top_level top_level_i
(
    .CHIP_HSI_CLK(CHIP_HSI_CLK),
    .CHIP_HSI_CMD(CHIP_HSI_CMD),
    .CHIP_HSI_DATA(CHIP_HSI_DATA),
    .CHIP_HSI_VALID(CHIP_HSI_VALID),
    .CHIP_RESET_N(CHIP_RESET_N),
    .CHIP_SPI_CLK(CHIP_SPI_CLK),
    .CHIP_SPI_CSN(CHIP_SPI_CSN),
    .CHIP_SPI_MISO(CHIP_SPI_MISO),
    .CHIP_SPI_MOSI(CHIP_SPI_MOSI),
    .CHIP_VDD(CHIP_VDD),
    .CHIP_VDDA(CHIP_VDDA),
    .CHIP_VDDIO(CHIP_VDDIO),
    .CHIP_VDDLVDS(CHIP_VDDLVDS),
    .LVL_TRSL_OE_N(LVL_TRSL_OE_N),
    .UCI_ADC_CSN(UCI_ADC_CSN),
    .UCI_ADC_MISO(UCI_ADC_MISO),
    .UCI_ADC_MOSI(UCI_ADC_MOSI),
    .UCI_ADC_SCK(UCI_ADC_SCK),
    .pcie_mgt_rxn(pcie_mgt_rxn),
    .pcie_mgt_rxp(pcie_mgt_rxp),
    .pcie_mgt_txn(pcie_mgt_txn),
    .pcie_mgt_txp(pcie_mgt_txp),
    .pcie_refclk_clk_n(pcie_refclk_clk_n),
    .pcie_refclk_clk_p(pcie_refclk_clk_p),
    .qsfp0_clk_clk_n(qsfp0_clk_clk_n),
    .qsfp0_clk_clk_p(qsfp0_clk_clk_p),
    .qsfp0_gt_grx_n(qsfp0_gt_grx_n),
    .qsfp0_gt_grx_p(qsfp0_gt_grx_p),
    .qsfp0_gt_gtx_n(qsfp0_gt_gtx_n),
    .qsfp0_gt_gtx_p(qsfp0_gt_gtx_p),
    .qsfp0_up(qsfp0_up),
    .qsfp1_clk_clk_n(qsfp1_clk_clk_n),
    .qsfp1_clk_clk_p(qsfp1_clk_clk_p),
    .qsfp1_gt_grx_n(qsfp1_gt_grx_n),
    .qsfp1_gt_grx_p(qsfp1_gt_grx_p),
    .qsfp1_gt_gtx_n(qsfp1_gt_gtx_n),
    .qsfp1_gt_gtx_p(qsfp1_gt_gtx_p),
    .qsfp1_up(qsfp1_up)
);

endmodule
