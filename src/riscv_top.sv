`include "src/definitions.vh"

module riscv_top (
    input wire i_clk,
    input wire i_rst,
    output wire [`DATA_WIDTH-1:0] debug
);

    // ==============================================================================
    // INTERNAL CPU DATAPATH WIRE DECLARATIONS
    // ==============================================================================
    // Program Counter Signals
    reg  [`DATA_WIDTH-1:0] pc;
    wire [`DATA_WIDTH-1:0] pc_next;
    wire [`DATA_WIDTH-1:0] pc_plus_4;

    // Instruction Bus
    wire [`INST_WIDTH-1:0] inst;

    // Decoder Output Control Signals
    wire [`OPCODE-1:0] opcode;
    wire [5:0] o_alu_op;
    wire o_alu_src_a;
    wire o_alu_src_b;
    wire o_branch;
    wire [2:0] o_branch_op;
    wire o_mem_write;
    wire [1:0] o_result_mux;
    wire o_reg_write;
    wire [1:0] mem_size;
    wire load_unsigned;
    
    // Register Address Buses
    wire [$clog2(`NUM_REGISTER)-1:0] rs1_addr;
    wire [$clog2(`NUM_REGISTER)-1:0] rs2_addr;
    wire [$clog2(`NUM_REGISTER)-1:0] rd_addr;

    // Register File Data Buses
    wire [`DATA_WIDTH-1:0] reg_rd_data1;
    wire [`DATA_WIDTH-1:0] reg_rd_data2;
    wire [`DATA_WIDTH-1:0] reg_wr_data;

    // Immediate Generation Bus
    wire [`DATA_WIDTH-1:0] imm;

    // ALU Input Muxes and Arithmetic Buses
    wire [`DATA_WIDTH-1:0] alu_operand_a;
    wire [`DATA_WIDTH-1:0] alu_operand_b;
    wire [`DATA_WIDTH-1:0] alu_result;

    // Data Memory Input/Output Wires
    wire [`DATA_WIDTH-1:0] mem_o_data;
    wire [(3 * `DATA_WIDTH)-1:0] mem_rd_data;

    // Branch Control Evaluation Line
    wire branch_take;

    // ==============================================================================
    // SEQUENTIAL LOGIC: PROGRAM COUNTER REGISTER
    // ==============================================================================
    always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            pc <= 32'h0000_0000;
        end else begin
            pc <= pc_next;
        end
    end

    // Sequential Next-PC Adder 
    assign pc_plus_4 = pc + 32'd4;

    // Selects ALU Result on branch/jump take, else PC+4. JALR's target is
    // rs1+imm, which the ISA requires clearing bit 0 of (BEQ/BNE/etc and
    // JAL targets are inherently even already from their own immediate
    // encodings, so only JALR needs the explicit mask here).
    assign pc_next = branch_take
        ? ((opcode == `OP_JALR) ? {alu_result[31:1], 1'b0} : alu_result)
        : pc_plus_4;

    // ==============================================================================
    // CORE HARDWARE MODULE INSTANTIATIONS
    // ==============================================================================

    // Instruction Memory Internal ROM Block
    instruction_memory u_instruction_memory (
        .clk(i_clk),
        .addr(pc[20:0]),
        .inst(inst)
    );

    // Control Path Central Decoder
    decoder u_decoder (
        .i_inst(inst),
        .o_opcode(opcode),
        .o_branch(o_branch),
        .o_result_mux(o_result_mux),
        .o_branch_op(o_branch_op),
        .o_mem_write(o_mem_write),
        .o_alu_src_a(o_alu_src_a),
        .o_alu_src_b(o_alu_src_b),
        .o_reg_write(o_reg_write),
        .o_alu_op(o_alu_op),
        .o_rs1_addr(rs1_addr),
        .o_rs2_addr(rs2_addr),
        .o_rd_addr(rd_addr),
        .o_mem_size(mem_size),
        .o_load_unsigned(load_unsigned)
    );

    // Immediate Field Sign Extension Unit
    sign_extension u_sign_extension (
        .i_inst(inst),
        .i_opcode(opcode),
        .o_immediate_extended(imm)
    );

    // Architectural Register File
    register_file u_register_file (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_we(o_reg_write),
        .i_rd_addr(rd_addr),
        .i_rs1_addr(rs1_addr),
        .i_rs2_addr(rs2_addr),
        .i_rd(reg_wr_data),
        .o_rs1(reg_rd_data1),
        .o_rs2(reg_rd_data2)
    );

    // ALU Input Operand Selection Multiplexers
    assign alu_operand_a = o_alu_src_a ? reg_rd_data1 : pc;
    assign alu_operand_b = o_alu_src_b ?  reg_rd_data2 : imm;

    // Central Execution ALU Unit
    alu u_alu_unit (
        .i_a(alu_operand_a),
        .i_b(alu_operand_b),
        .i_alu_op(o_alu_op),
        .o_c(alu_result)
    );

    // Condition Evaluation Branch Unit
    branch_unit u_branch_unit (
        .i_branch(o_branch),
        .i_branch_op(o_branch_op),
        .i_a(reg_rd_data1),
        .i_b(reg_rd_data2),
        .o_take(branch_take)
    );

    // Synchronous Data Memory RAM Block
    data_memory u_data_memory (
        .i_clk(i_clk),
        .i_we(o_mem_write),
        .i_size(mem_size),
        .i_data(reg_rd_data2),
        .i_addr(alu_result[13:0]),
        .o_data(mem_o_data)
    );

    // Sub-word load formatting: data_memory always returns the full word
    // containing the addressed byte/halfword, so LB/LH/LBU/LHU need to
    // pull out just their lane and sign- or zero-extend it to 32 bits.
    // LW (mem_size==2'b10) passes the word through unchanged.
    wire [7:0]  load_byte = mem_o_data[(alu_result[1:0] * 8) +: 8];
    wire [15:0] load_half = mem_o_data[(alu_result[1]   * 16) +: 16];
    wire [31:0] load_data =
        (mem_size == 2'b00) ? (load_unsigned ? {24'b0, load_byte} : {{24{load_byte[7]}}, load_byte}) :
        (mem_size == 2'b01) ? (load_unsigned ? {16'b0, load_half} : {{16{load_half[15]}}, load_half}) :
        mem_o_data;

    // ==============================================================================
    // WRITE-BACK SELECTION (Standard RISC-V Mux)
    // ==============================================================================
    assign reg_wr_data = (o_result_mux == 2'b00) ? alu_result :
                         (o_result_mux == 2'b01) ? pc_plus_4 :
                         (o_result_mux == 2'b10) ? load_data : 32'h0000_0000;
    
    // Connect the selected write-back data bus straight to the external debug output port
    assign debug = reg_wr_data;

endmodule