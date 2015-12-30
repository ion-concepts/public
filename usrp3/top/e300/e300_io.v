//------------------------------------------------------------------
//
// In SISO mode, we output a clock thats 1x the frequency of the Catalina
// source-synchronous bus clock to be used as the radio_clk.
// In MIMO mode, we output a clock thats 1/2 the frequency of the Catalina
// source-synchronous bus clock to be used as the radio_clk.
//
//------------------------------------------------------------------

module e300_io
    (
     input 	  mimo,

     // Baseband sample interface
     output 	  radio_clk,
     output [11:0] rx_i0,
     output [11:0] rx_q0,
     output [11:0] rx_i1,
     output [11:0] rx_q1,
     input [11:0]  tx_i0,
     input [11:0]  tx_q0,
     input [11:0]  tx_i1,
     input [11:0]  tx_q1,

     // Catalina interface
     input 	  rx_clk,
     input 	  rx_frame,
     input [11:0]  rx_data,
     output 	  tx_clk,
     output 	  tx_frame,
     output [11:0] tx_data
     );


   genvar 	   z;

   //------------------------------------------------------------------
   // Clock Buffering.
   // BUFIO2 drives all IDDR2 and ODDR2 cells directly in bank3.
   // Need two pairs of BUFIO2 one pair each for Top Left and Bottom Left half banks.
   //------------------------------------------------------------------
   wire 			rx_clk_buf;
   wire 			mimo_clk;
   wire 			siso_clk;
   wire 			siso_clk2;
   
   //------------------------------------------------------------------
   //
   // Synchronize MIMO signal from bus_clk to siso2_clk.
   //
   //------------------------------------------------------------------
   reg 		   mimo_sync, mimo_sync2;

   always @(posedge siso_clk2) begin
      mimo_sync <= mimo_sync2;
      mimo_sync2 <= mimo;
   end



   IBUFG clk_ibufg (.O(rx_clk_buf), .I(rx_clk));
   
   //------------------------------------------------------------------
   //
   // Buffer that drives all IO cells
   // BUFIO_
   //
   //------------------------------------------------------------------
   BUFIO clk_bufio
     (
      .I(rx_clk_buf),
      .O(io_clk)
      );

   //------------------------------------------------------------------
   //
   // Buffer that creates SISO logic clock
   // There are 2 clocks so that we can make a constraint that defines an
   // exclusive clock group for siso_clk and mimo_clk.
   // BUFR_
   //
   //------------------------------------------------------------------
   BUFR #(
	  .BUFR_DIVIDE(1))
     clk_bufr_siso
       (
	.I(rx_clk_buf),
	.O(siso_clk),
	.CE(1'b1),
	.CLR(1'b0)
	);

   BUFR #(
	  .BUFR_DIVIDE(1))
     clk_bufr_siso2
       (
	.I(rx_clk_buf),
	.O(siso_clk2),
	.CE(1'b1),
	.CLR(1'b0)
	);
   
   //------------------------------------------------------------------
   //
   // Buffer that creates MIMO logic clock
   // BUFR_
   //
   //------------------------------------------------------------------
   BUFR #(
	  .BUFR_DIVIDE(2))
     clk_bufr_mimo
       (
	.I(rx_clk_buf),
	.O(mimo_clk),
	.CE(1'b1),
	.CLR(1'b0)
	);
   
   
   
/* -----\/----- EXCLUDED -----\/-----
   //------------------------------------------------------------------
   //
   // Buffers for LEFT TOP half bank pins
   // BUFIO2_X0Y22
   //
   //------------------------------------------------------------------
   BUFIO2 #(
	    .DIVIDE(4),
	    .DIVIDE_BYPASS("FALSE"),
	    .I_INVERT("FALSE"),
	    .USE_DOUBLER("TRUE"))
     clk_bufio_lt
       (
	.IOCLK(io_clk_lt),
	.DIVCLK(mimo_clk_unbuf), // Non-inverted source of 1/2x interface clock for radio_clk
	.SERDESSTROBE(),
	.I(rx_clk_buf)
	);

   // BUFIO2_X0Y23
   BUFIO2 #(
	    .DIVIDE(1),
	    .DIVIDE_BYPASS("FALSE"),
	    .I_INVERT("TRUE"),
	    .USE_DOUBLER("FALSE"))
     clk_bufio_lt_b
       (
	.IOCLK(io_clk_lt_b),
	.DIVCLK(siso_clk2_unbuf), // Inverted source of 1x interface clock for radio_clk
	.SERDESSTROBE(),
	.I(rx_clk_buf)
	);

   //------------------------------------------------------------------
   //
   // Buffers for LEFT BOTTOM half bank pins
   // BUFIO2_X1Y14
   //
   //------------------------------------------------------------------
   BUFIO2 #(
	    .DIVIDE(1),
	    .DIVIDE_BYPASS("FALSE"),
	    .I_INVERT("FALSE"),
	    .USE_DOUBLER("FALSE"))
     clk_bufio_lb
       (
	.IOCLK(io_clk_lb),
	.DIVCLK(siso_clk_unbuf), // Non-inverted source of 1x interface clock for local IO use
	.SERDESSTROBE(),
	.I(rx_clk_buf)
	);

   // BUFIO2_X1Y15
   BUFIO2 #(
	    .DIVIDE(1),
	    .DIVIDE_BYPASS("FALSE"),
	    .I_INVERT("TRUE"),
	    .USE_DOUBLER("FALSE"))
     clk_bufio_lb_b
       (
	 .IOCLK(io_clk_lb_b),
	 .DIVCLK(),
	 .SERDESSTROBE(),
	 .I(rx_clk_buf)
	 );
 -----/\----- EXCLUDED -----/\----- */

   //------------------------------------------------------------------
   // Always-on SISO clk needed to load/unload DDR2 I/O Regs
   //------------------------------------------------------------------
/* -----\/----- EXCLUDED -----\/-----
   BUFG siso_clk_bufg (
		       .I(siso_clk_unbuf),
		       .O(siso_clk)
		       );
 -----/\----- EXCLUDED -----/\----- */

   //------------------------------------------------------------------
   // 2-1 mux combined with BUFG to drive global radio_clk.
   // Note: Not addressed setup/hold constraints of S input ...unsure if anything "bad" can happen here.
   //------------------------------------------------------------------
   BUFGMUX #(
	     .CLK_SEL_TYPE("SYNC"))
     radio_clk_bufg (
		     .I0(siso_clk),
		     .I1(mimo_clk),
		     .S(mimo_sync),
		     .O(radio_clk)
		     );

   //------------------------------------------------------------------
   // RX Frame Signal - In bank 3 LB
   //------------------------------------------------------------------
   wire              rx_frame_0, rx_frame_1;
   IDDR #(
	   .DDR_CLK_EDGE("SAME_EDGE"))
     iddr_frame (
		  .Q1(rx_frame_1),
		  .Q2(rx_frame_0),
		  .C(io_clk),
		  .CE(1'b1),
		  .D(rx_frame),
		  .R(1'b0),
		  .S(1'b0));


/* -----\/----- EXCLUDED -----\/-----
   IDDR2 #(
	   .DDR_ALIGNMENT("C0"))
     iddr2_frame (
		  .Q0(rx_frame_1),
		  .Q1(rx_frame_0),
		  .C0(io_clk_lb),
		  .C1(io_clk_lb_b),
		  .CE(1'b1),
		  .D(rx_frame),
		  .R(1'b0),
		  .S(1'b0));

 -----/\----- EXCLUDED -----/\----- */
   reg rx_frame_d1, rx_frame_d2;
   always @(posedge siso_clk2)
     if(~mimo_sync)
       { rx_frame_d2, rx_frame_d1 } <= { rx_frame_1, 1'b0 };
     else
       { rx_frame_d2, rx_frame_d1 } <= { rx_frame_d1, rx_frame_1 };

   //------------------------------------------------------------------
   // RX Data Bus - In bank3 both LT and LB
   //------------------------------------------------------------------
   wire [11:0] rx_i,rx_q;

	 // Bit0 LB
         IDDR #(
		 .DDR_CLK_EDGE("SAME_EDGE"))
         iddr_i0 (
		   .Q1(rx_q[0]),
		   .Q2(rx_i[0]),
		   .C(io_clk),
		   .CE(1'b1),
		   .D(rx_data[0]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit1 LB
         IDDR #(
		 .DDR_CLK_EDGE("SAME_EDGE"))
         iddr_i1 (
		   .Q1(rx_q[1]),
		   .Q2(rx_i[1]),
		   .C(io_clk),
		   .CE(1'b1),
		   .D(rx_data[1]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit2 LB
         IDDR #(
		 .DDR_CLK_EDGE("SAME_EDGE"))
         iddr_i2 (
		   .Q1(rx_q[2]),
		   .Q2(rx_i[2]),
		   .C(io_clk),
		   .CE(1'b1),
		   .D(rx_data[2]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit3 LT
         IDDR #(
		 .DDR_CLK_EDGE("SAME_EDGE"))
         iddr_i3 (
		   .Q1(rx_q[3]),
		   .Q2(rx_i[3]),
		   .C(io_clk),
		   .CE(1'b1),
		   .D(rx_data[3]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit4 LB
         IDDR #(
		 .DDR_CLK_EDGE("SAME_EDGE"))
         iddr_i4 (
		   .Q1(rx_q[4]),
		   .Q2(rx_i[4]),
		   .C(io_clk),
		   .CE(1'b1),
		   .D(rx_data[4]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit5 LT
         IDDR #(
		 .DDR_CLK_EDGE("SAME_EDGE"))
         iddr_i5 (
		   .Q1(rx_q[5]),
		   .Q2(rx_i[5]),
		   .C(io_clk),
		   .CE(1'b1),
		   .D(rx_data[5]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit6 LB
         IDDR #(
		 .DDR_CLK_EDGE("SAME_EDGE"))
         iddr_i6 (
		   .Q1(rx_q[6]),
		   .Q2(rx_i[6]),
		   .C(io_clk),
		   .CE(1'b1),
		   .D(rx_data[6]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit7 LT
         IDDR #(
		 .DDR_CLK_EDGE("SAME_EDGE"))
         iddr_i7 (
		   .Q1(rx_q[7]),
		   .Q2(rx_i[7]),
		   .C(io_clk),
		   .CE(1'b1),
		   .D(rx_data[7]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit8 LB
         IDDR #(
		 .DDR_CLK_EDGE("SAME_EDGE"))
         iddr_i8 (
		   .Q1(rx_q[8]),
		   .Q2(rx_i[8]),
		   .C(io_clk),
		   .CE(1'b1),
		   .D(rx_data[8]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit9 LT
         IDDR #(
		 .DDR_CLK_EDGE("SAME_EDGE"))
         iddr_i9 (
		   .Q1(rx_q[9]),
		   .Q2(rx_i[9]),
		   .C(io_clk),
		   .CE(1'b1),
		   .D(rx_data[9]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit10 LB
         IDDR #(
		 .DDR_CLK_EDGE("SAME_EDGE"))
         iddr_i10 (
		    .Q1(rx_q[10]),
		    .Q2(rx_i[10]),
		    .C(io_clk),
		    .CE(1'b1),
		    .D(rx_data[10]),
		    .R(1'b0),
		    .S(1'b0));

	 // Bit11 LB
         IDDR #(
		 .DDR_CLK_EDGE("SAME_EDGE"))
         iddr_i11 (
		    .Q1(rx_q[11]),
		    .Q2(rx_i[11]),
		    .C(io_clk),
		    .CE(1'b1),
		    .D(rx_data[11]),
		    .R(1'b0),
		    .S(1'b0));

/* -----\/----- EXCLUDED -----\/-----
	 // Bit0 LB
         IDDR2 #(
		 .DDR_ALIGNMENT("C0"))
         iddr2_i0 (
		   .Q0(rx_q[0]),
		   .Q1(rx_i[0]),
		   .C0(io_clk_lb),
		   .C1(io_clk_lb_b),
		   .CE(1'b1),
		   .D(rx_data[0]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit1 LB
         IDDR2 #(
		 .DDR_ALIGNMENT("C0"))
         iddr2_i1 (
		   .Q0(rx_q[1]),
		   .Q1(rx_i[1]),
		   .C0(io_clk_lb),
		   .C1(io_clk_lb_b),
		   .CE(1'b1),
		   .D(rx_data[1]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit2 LB
         IDDR2 #(
		 .DDR_ALIGNMENT("C0"))
         iddr2_i2 (
		   .Q0(rx_q[2]),
		   .Q1(rx_i[2]),
		   .C0(io_clk_lb),
		   .C1(io_clk_lb_b),
		   .CE(1'b1),
		   .D(rx_data[2]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit3 LT
         IDDR2 #(
		 .DDR_ALIGNMENT("C0"))
         iddr2_i3 (
		   .Q0(rx_q[3]),
		   .Q1(rx_i[3]),
		   .C0(io_clk_lt),
		   .C1(io_clk_lt_b),
		   .CE(1'b1),
		   .D(rx_data[3]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit4 LB
         IDDR2 #(
		 .DDR_ALIGNMENT("C0"))
         iddr2_i4 (
		   .Q0(rx_q[4]),
		   .Q1(rx_i[4]),
		   .C0(io_clk_lb),
		   .C1(io_clk_lb_b),
		   .CE(1'b1),
		   .D(rx_data[4]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit5 LT
         IDDR2 #(
		 .DDR_ALIGNMENT("C0"))
         iddr2_i5 (
		   .Q0(rx_q[5]),
		   .Q1(rx_i[5]),
		   .C0(io_clk_lt),
		   .C1(io_clk_lt_b),
		   .CE(1'b1),
		   .D(rx_data[5]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit6 LB
         IDDR2 #(
		 .DDR_ALIGNMENT("C0"))
         iddr2_i6 (
		   .Q0(rx_q[6]),
		   .Q1(rx_i[6]),
		   .C0(io_clk_lb),
		   .C1(io_clk_lb_b),
		   .CE(1'b1),
		   .D(rx_data[6]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit7 LT
         IDDR2 #(
		 .DDR_ALIGNMENT("C0"))
         iddr2_i7 (
		   .Q0(rx_q[7]),
		   .Q1(rx_i[7]),
		   .C0(io_clk_lt),
		   .C1(io_clk_lt_b),
		   .CE(1'b1),
		   .D(rx_data[7]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit8 LB
         IDDR2 #(
		 .DDR_ALIGNMENT("C0"))
         iddr2_i8 (
		   .Q0(rx_q[8]),
		   .Q1(rx_i[8]),
		   .C0(io_clk_lb),
		   .C1(io_clk_lb_b),
		   .CE(1'b1),
		   .D(rx_data[8]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit9 LT
         IDDR2 #(
		 .DDR_ALIGNMENT("C0"))
         iddr2_i9 (
		   .Q0(rx_q[9]),
		   .Q1(rx_i[9]),
		   .C0(io_clk_lt),
		   .C1(io_clk_lt_b),
		   .CE(1'b1),
		   .D(rx_data[9]),
		   .R(1'b0),
		   .S(1'b0));

	 // Bit10 LB
         IDDR2 #(
		 .DDR_ALIGNMENT("C0"))
         iddr2_i10 (
		    .Q0(rx_q[10]),
		    .Q1(rx_i[10]),
		    .C0(io_clk_lb),
		    .C1(io_clk_lb_b),
		    .CE(1'b1),
		    .D(rx_data[10]),
		    .R(1'b0),
		    .S(1'b0));

	 // Bit11 LB
         IDDR2 #(
		 .DDR_ALIGNMENT("C0"))
         iddr2_i11 (
		    .Q0(rx_q[11]),
		    .Q1(rx_i[11]),
		    .C0(io_clk_lb),
		    .C1(io_clk_lb_b),
		    .CE(1'b1),
		    .D(rx_data[11]),
		    .R(1'b0),
		    .S(1'b0));
 -----/\----- EXCLUDED -----/\----- */

   //------------------------------------------------------------------
   //
   // De-mux I & Q, Ch A & B onto fullrate clock.
   //
   // In all modes we grab data from the IDDR2 using negedge of siso_clk.
   // IDDR2 updates all Q pins on posedge of io_clk. siso_clk does not have aligned phase
   // with siso_clk...siso_clk is always a little more delayed than io_clk.
   // This small delay is always much smaller than half a clk cycle. Thus by sampling the Q outputs
   // with negedge siso_clk we avoid any risk of a race condition (hold violation on receiveing register).
   //
   // In SISO mode data is replicated onto both CH0 and CH1 for max flexibility in using the DDC's.
   //
   //------------------------------------------------------------------
   reg [11:0] rx_i_del, rx_q_del;
   reg [11:0] rx_i0_siso_pos;
   reg [11:0] rx_q0_siso_pos;
   reg [11:0] rx_i1_siso_pos;
   reg [11:0] rx_q1_siso_pos;
   reg [11:0] rx_i0_siso_neg;
   reg [11:0] rx_q0_siso_neg;
   reg [11:0] rx_i1_siso_neg;
   reg [11:0] rx_q1_siso_neg;
   reg [11:0] rx_i0_siso;
   reg [11:0] rx_q0_siso;
   reg [11:0] rx_i1_siso;
   reg [11:0] rx_q1_siso;


   always @(negedge siso_clk2)
     if(mimo_sync)
       // rx_frame_0 was sampled by same falling io_clk edge as rx_i[x]
       // rx_frame_0 == 0 causes I & Q to be allocated to CH0
       if(rx_frame_0) begin
	  rx_i_del[11:0] <= rx_i[11:0];
	  rx_q_del[11:0] <= rx_q[11:0];
       end
       else begin
	  // AD9361 map correctly to labeled connectors on E310 (unlike B200).
	  rx_i1_siso[11:0] <= rx_i[11:0];
	  rx_q1_siso[11:0] <= rx_q[11:0];
	  rx_i0_siso[11:0] <= rx_i_del[11:0];
	  rx_q0_siso[11:0] <= rx_q_del[11:0];
       end
     else begin
	rx_i0_siso[11:0] <= rx_i[11:0];
	rx_q0_siso[11:0] <= rx_q[11:0];
	rx_i1_siso[11:0] <= rx_i[11:0];
	rx_q1_siso[11:0] <= rx_q[11:0];
     end // else: !if(rx_frame_0)

   //------------------------------------------------------------------
   //
   // Now prepare data for crossing into radio_clk domain which can be for SISO mode (inverted) siso_clk or for MIMO mode siso_clk/2.
   // In MIMO mode tx_strobe is used to maintain a known phase relationship betwwen siso_clk and radio_clk.
   // (Note: Negedge or posedge is used conditionally so that we have massive margin against a fast-path race condition
   // betwwen siso_clk and radio_clk). This kind of arrangement could still lead to confusion in timing analysis
   // even if it works in the real world depending on how well the STA tool can do automatic case analysis.
   //
   //------------------------------------------------------------------
   // This code lock only relevent in MIMO mode.
   always @(negedge siso_clk2)
     if (tx_strobe)
       begin
	  rx_i0_siso_neg[11:0] <= rx_i0_siso[11:0];
	  rx_q0_siso_neg[11:0] <= rx_q0_siso[11:0];
	  rx_i1_siso_neg[11:0] <= rx_i1_siso[11:0];
	  rx_q1_siso_neg[11:0] <= rx_q1_siso[11:0];
       end
   // This code block only relevent in SISO mode.
   always @(posedge siso_clk2)
     begin
	rx_i0_siso_pos[11:0] <= rx_i0_siso[11:0];
	rx_q0_siso_pos[11:0] <= rx_q0_siso[11:0];
	rx_i1_siso_pos[11:0] <= rx_i1_siso[11:0];
	rx_q1_siso_pos[11:0] <= rx_q1_siso[11:0];
     end

   assign rx_i0 = (mimo_sync) ? rx_i0_siso_neg : rx_i0_siso_pos;
   assign rx_q0 = (mimo_sync) ? rx_q0_siso_neg : rx_q0_siso_pos;
   assign rx_i1 = (mimo_sync) ? rx_i1_siso_neg : rx_i1_siso_pos;
   assign rx_q1 = (mimo_sync) ? rx_q1_siso_neg : rx_q1_siso_pos;


   //------------------------------------------------------------------
   // TX Data Bus - In bank3 LB
   //------------------------------------------------------------------
  reg [11:0]      tx_i,tx_q;
  reg             tx_strobe_del;

   generate
      for(z = 0; z < 12; z = z + 1)
	begin : gen_pins
	   ODDR #(
		   .DDR_CLK_EDGE("SAME_EDGE"), .SRTYPE("ASYNC"))
             oddr (
		    .Q(tx_data[z]), .C(io_clk),
		    .CE(1'b1), .D1(tx_i[z]), .D2(tx_q[z]), .R(1'b0), .S(1'b0));

/* -----\/----- EXCLUDED -----\/-----
           ODDR2 #(
		   .DDR_ALIGNMENT("C0"), .SRTYPE("ASYNC"))
             oddr2 (
		    .Q(tx_data[z]), .C0(io_clk_lb), .C1(io_clk_lb_b),
		    .CE(1'b1), .D0(tx_i[z]), .D1(tx_q[z]), .R(1'b0), .S(1'b0));
 -----/\----- EXCLUDED -----/\----- */
	end
   endgenerate

   //------------------------------------------------------------------
   // TX Frame Signal - In bank 3 LB
   //------------------------------------------------------------------
/* -----\/----- EXCLUDED -----\/-----
   ODDR2 #(
           .DDR_ALIGNMENT("C0"), .SRTYPE("ASYNC"))
     oddr2_frame (
		  .Q(tx_frame), .C0(io_clk_lb), .C1(io_clk_lb_b),
		  .CE(1'b1), .D0(tx_strobe_del), .D1(mimo_sync & tx_strobe_del), .R(1'b0), .S(1'b0));
 -----/\----- EXCLUDED -----/\----- */
   ODDR #(
           .DDR_CLK_EDGE("SAME_EDGE"), .SRTYPE("ASYNC"))
     oddr_frame (
		  .Q(tx_frame), .C(io_clk),
		  .CE(1'b1), .D1(tx_strobe_del), .D2(mimo_sync & tx_strobe_del), .R(1'b0), .S(1'b0));
 
   //------------------------------------------------------------------
   // TX Clock Signal - In bank 3 LB
   //------------------------------------------------------------------
/* -----\/----- EXCLUDED -----\/-----
   ODDR2 #(
           .DDR_ALIGNMENT("C0"), .SRTYPE("ASYNC"))
     oddr2_clk (
		.Q(tx_clk), .C0(io_clk_lb), .C1(io_clk_lb_b),
		.CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));
 -----/\----- EXCLUDED -----/\----- */
   ODDR #(
         .DDR_CLK_EDGE("SAME_EDGE"), .SRTYPE("ASYNC"))
     oddr_clk (
	       .Q(tx_clk), .C(io_clk),
	       .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));

   //------------------------------------------------------------------
   //
   // Mux I & Q, Ch A & B onto fullrate clockTX bus to AD9361
   //
   //------------------------------------------------------------------
   wire tx_strobe;
   reg [11:0] tx_i_del, tx_q_del;

   reg 	      find_radio_clk_phase = 1'b0;
   reg 	      find_radio_clk_phase_del;


   always @(posedge radio_clk)
     find_radio_clk_phase <= ~find_radio_clk_phase;

   always @(negedge radio_clk)
      find_radio_clk_phase_del <= find_radio_clk_phase;

   assign     tx_strobe = mimo_sync ? (find_radio_clk_phase_del ^ find_radio_clk_phase) : 1'b1;

   always @(posedge siso_clk2)
     tx_strobe_del <= tx_strobe;

   // This strange piece of logic allows either USRP DUC to drive the AD9361 in SISO mode.
   // This is principly used in the CODEC loopback test.
   wire [11:0] tx_im = (mimo_sync ||  tx_i0 != 12'h0) ? tx_i0 : tx_i1;
   wire [11:0] tx_qm = (mimo_sync ||  tx_q0 != 12'h0) ? tx_q0 : tx_q1;


   // Ch A and Ch B are correctly labelled in silkscreen w.r.t AD9361 on E310
   always @(posedge siso_clk2)
     if(tx_strobe)
       begin
	  {tx_i,tx_q} <= mimo_sync ? {tx_i0,tx_q0} : {tx_im,tx_qm};
	  {tx_i_del,tx_q_del} <= {tx_i1,tx_q1};
       end
     else
       {tx_i,tx_q} <= {tx_i_del,tx_q_del};
   //
   // Debug
   //
/* -----\/----- EXCLUDED -----\/-----
   wire [35:0] CONTROL0;
   reg [11:0]  tx_i_del_debug, tx_q_del_debug;
   reg [11:0]  tx_i_debug,tx_q_debug;
   reg [11:0]  tx_i0_debug,tx_q0_debug;
   reg 	       find_radio_clk_phase_debug;
   reg 	       find_radio_clk_phase_del_debug;
   reg 	       tx_strobe_debug;
   reg 	       tx_strobe_del_debug;


   always @(posedge siso_clk) begin
      tx_i_del_debug <= tx_i_del;
      tx_q_del_debug <= tx_q_del;
      tx_i_debug <= tx_i;
      tx_q_debug <= tx_q;
      tx_i0_debug <=tx_i0;
      tx_q0_debug <= tx_q0;
      find_radio_clk_phase_debug <= find_radio_clk_phase;
      find_radio_clk_phase_del_debug <= find_radio_clk_phase_del;
      tx_strobe_debug <= tx_strobe;
      tx_strobe_del_debug <= tx_strobe_del;
   end



   chipscope_icon chipscope_icon_i0
     (
      .CONTROL0(CONTROL0) // INOUT BUS [35:0]
      );

   chipscope_ila_128 chipscope_ila_i0
     (
      .CONTROL(CONTROL0), // INOUT BUS [35:0]
      .CLK(siso_clk), // IN
      .TRIG0(
	     {
	      tx_i_del_debug[11:0],
	      tx_q_del_debug[11:0],
	      tx_i_debug[11:0],
	      tx_q_debug[11:0],
	      tx_i0_debug[11:0],
	      tx_q0_debug[11:0],
	      find_radio_clk_phase_debug,
	      find_radio_clk_phase_del_debug,
	      tx_strobe_debug,
	      tx_strobe_del_debug
	      }
	     )

      );
    -----/\----- EXCLUDED -----/\----- */
endmodule