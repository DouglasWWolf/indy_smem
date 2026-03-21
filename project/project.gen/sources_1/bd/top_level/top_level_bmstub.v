// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
// -------------------------------------------------------------------------------

`timescale 1 ps / 1 ps

(* BLOCK_STUB = "true" *)
module top_level (
  pcie_refclk_clk_p,
  pcie_refclk_clk_n,
  pcie_mgt_rxn,
  pcie_mgt_rxp,
  pcie_mgt_txn,
  pcie_mgt_txp,
  qsfp0_gt_grx_n,
  qsfp0_gt_grx_p,
  qsfp0_gt_gtx_n,
  qsfp0_gt_gtx_p,
  qsfp0_clk_clk_n,
  qsfp0_clk_clk_p,
  qsfp1_gt_grx_n,
  qsfp1_gt_grx_p,
  qsfp1_gt_gtx_n,
  qsfp1_gt_gtx_p,
  qsfp1_clk_clk_n,
  qsfp1_clk_clk_p,
  qsfp0_up,
  qsfp1_up,
  CHIP_HSI_CLK,
  CHIP_HSI_CMD,
  CHIP_HSI_DATA,
  CHIP_HSI_VALID,
  CHIP_SPI_CLK,
  CHIP_SPI_CSN,
  CHIP_SPI_MOSI,
  CHIP_SPI_MISO,
  CHIP_VDDIO,
  CHIP_VDD,
  CHIP_VDDLVDS,
  CHIP_VDDA,
  CHIP_RESET_N,
  UCI_ADC_CSN,
  UCI_ADC_SCK,
  UCI_ADC_MOSI,
  UCI_ADC_MISO,
  LVL_TRSL_OE_N
);

  (* X_INTERFACE_INFO = "xilinx.com:interface:diff_clock:1.0 pcie_refclk CLK_P" *)
  (* X_INTERFACE_MODE = "slave pcie_refclk" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME pcie_refclk, CAN_DEBUG false, FREQ_HZ 100000000" *)
  input [0:0]pcie_refclk_clk_p;
  (* X_INTERFACE_INFO = "xilinx.com:interface:diff_clock:1.0 pcie_refclk CLK_N" *)
  input [0:0]pcie_refclk_clk_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:pcie_7x_mgt:1.0 pcie_mgt rxn" *)
  (* X_INTERFACE_MODE = "master pcie_mgt" *)
  input [15:0]pcie_mgt_rxn;
  (* X_INTERFACE_INFO = "xilinx.com:interface:pcie_7x_mgt:1.0 pcie_mgt rxp" *)
  input [15:0]pcie_mgt_rxp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:pcie_7x_mgt:1.0 pcie_mgt txn" *)
  output [15:0]pcie_mgt_txn;
  (* X_INTERFACE_INFO = "xilinx.com:interface:pcie_7x_mgt:1.0 pcie_mgt txp" *)
  output [15:0]pcie_mgt_txp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:gt:1.0 qsfp0_gt GRX_N" *)
  (* X_INTERFACE_MODE = "master qsfp0_gt" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME qsfp0_gt, CAN_DEBUG false" *)
  input [3:0]qsfp0_gt_grx_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:gt:1.0 qsfp0_gt GRX_P" *)
  input [3:0]qsfp0_gt_grx_p;
  (* X_INTERFACE_INFO = "xilinx.com:interface:gt:1.0 qsfp0_gt GTX_N" *)
  output [3:0]qsfp0_gt_gtx_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:gt:1.0 qsfp0_gt GTX_P" *)
  output [3:0]qsfp0_gt_gtx_p;
  (* X_INTERFACE_INFO = "xilinx.com:interface:diff_clock:1.0 qsfp0_clk CLK_N" *)
  (* X_INTERFACE_MODE = "slave qsfp0_clk" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME qsfp0_clk, CAN_DEBUG false, FREQ_HZ 322265625" *)
  input qsfp0_clk_clk_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:diff_clock:1.0 qsfp0_clk CLK_P" *)
  input qsfp0_clk_clk_p;
  (* X_INTERFACE_INFO = "xilinx.com:interface:gt:1.0 qsfp1_gt GRX_N" *)
  (* X_INTERFACE_MODE = "master qsfp1_gt" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME qsfp1_gt, CAN_DEBUG false" *)
  input [3:0]qsfp1_gt_grx_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:gt:1.0 qsfp1_gt GRX_P" *)
  input [3:0]qsfp1_gt_grx_p;
  (* X_INTERFACE_INFO = "xilinx.com:interface:gt:1.0 qsfp1_gt GTX_N" *)
  output [3:0]qsfp1_gt_gtx_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:gt:1.0 qsfp1_gt GTX_P" *)
  output [3:0]qsfp1_gt_gtx_p;
  (* X_INTERFACE_INFO = "xilinx.com:interface:diff_clock:1.0 qsfp1_clk CLK_N" *)
  (* X_INTERFACE_MODE = "slave qsfp1_clk" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME qsfp1_clk, CAN_DEBUG false, FREQ_HZ 322265625" *)
  input qsfp1_clk_clk_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:diff_clock:1.0 qsfp1_clk CLK_P" *)
  input qsfp1_clk_clk_p;
  (* X_INTERFACE_IGNORE = "true" *)
  output [0:0]qsfp0_up;
  (* X_INTERFACE_IGNORE = "true" *)
  output [0:0]qsfp1_up;
  (* X_INTERFACE_IGNORE = "true" *)
  output CHIP_HSI_CLK;
  (* X_INTERFACE_IGNORE = "true" *)
  output CHIP_HSI_CMD;
  (* X_INTERFACE_IGNORE = "true" *)
  output [31:0]CHIP_HSI_DATA;
  (* X_INTERFACE_IGNORE = "true" *)
  output CHIP_HSI_VALID;
  (* X_INTERFACE_IGNORE = "true" *)
  output CHIP_SPI_CLK;
  (* X_INTERFACE_IGNORE = "true" *)
  output CHIP_SPI_CSN;
  (* X_INTERFACE_IGNORE = "true" *)
  output CHIP_SPI_MOSI;
  (* X_INTERFACE_IGNORE = "true" *)
  input CHIP_SPI_MISO;
  (* X_INTERFACE_IGNORE = "true" *)
  output CHIP_VDDIO;
  (* X_INTERFACE_IGNORE = "true" *)
  output CHIP_VDD;
  (* X_INTERFACE_IGNORE = "true" *)
  output CHIP_VDDLVDS;
  (* X_INTERFACE_IGNORE = "true" *)
  output CHIP_VDDA;
  (* X_INTERFACE_IGNORE = "true" *)
  output CHIP_RESET_N;
  (* X_INTERFACE_IGNORE = "true" *)
  output [2:0]UCI_ADC_CSN;
  (* X_INTERFACE_IGNORE = "true" *)
  output UCI_ADC_SCK;
  (* X_INTERFACE_IGNORE = "true" *)
  output UCI_ADC_MOSI;
  (* X_INTERFACE_IGNORE = "true" *)
  input UCI_ADC_MISO;
  (* X_INTERFACE_IGNORE = "true" *)
  output LVL_TRSL_OE_N;

  // stub module has no contents

endmodule
