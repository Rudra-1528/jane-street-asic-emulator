`timescale 1ns / 1ps



module Uart(
    input clk,
    input start,
    input reset,
    input [15:0] baud_div,
    input [7:0] txin,
    output reg tx,
    input rx,
    output [7:0] rxout,
    output rxdone, txdone
    );
      
 //// 2-Stage Synchronizer
  reg rx_sync1;
  reg rx_sync2;
  
  always @(posedge clk or posedge reset) begin
    if (reset) begin
        rx_sync1 <= 1'b1; 
        rx_sync2 <= 1'b1;
    end else begin
        rx_sync1 <= rx;
        rx_sync2 <= rx_sync1;
    end
end
  
  
  //////////////////////////// 16x Baud Tick baud_div
  
 integer count;
 wire tick_16x = (count == baud_div); // Fires 16 times per baud bit

    always @(posedge clk) begin
        if (reset) 
        count <= 0;
        else if (tick_16x) 
        count <= 0;
        else 
        count <= count + 1;
    end
  
  
  //////////////////////////////////// TX 
  
  reg [3:0] tx_sub_count;
  wire bitdone = (tick_16x && tx_sub_count == 15);
    
    always @(posedge clk) begin
         if (reset) 
         tx_sub_count <= 0;
         else if (tick_16x) 
         tx_sub_count <= tx_sub_count + 1;
    end
  
  
  reg [9:0] txData,shiftx;
  integer bitindex;
  
  parameter idle =0, send = 1, check = 2;
  reg [1:0] state =idle;
  
  always @(posedge clk)
   begin
    case (state)
     idle:
       begin 
         tx <= 1'b1;
         txData <= 0;
         bitindex <=0;
         shiftx <= 0;
         
         if (start == 1)
          begin
            txData <= {1'b1,txin,1'b0};
            state <= send ;
          end 
         else
          state <= idle;
       end 
      
       
      send :
        begin
          tx <= txData[bitindex];
          state <= check ;
          shiftx <= {txData,shiftx[9:1]};
         end
           
      check :
         begin
            if (bitindex <= 9)
              begin
               if (bitdone == 1)
                begin
                 state <= send;
                 bitindex <= bitindex + 1;
                end 
               else
                state <= check; 
              end
            else
              state <= idle ;
          end
        
        default : state <= idle;
        
      endcase
    end                       
             
     assign txdone = (bitindex == 9 && bitdone == 1'b1)? 1'b1 : 1'b0;
          
          
          
          
 /////////////////////////////////// RX 
 integer rindex;
 parameter ridle = 0, rwait = 1, recv = 2;
 reg [1:0] rstate;
 reg [9:0] rxdata;

 reg [3:0] rcount;          // Counts the 16 sub-ticks
 reg s1, s2, s3;
 
 // The Majority Voter Logic
 wire voted_bit = (s1 & s2) | (s2 & s3) | (s1 & s3);
   
 always @(posedge clk) begin
    if (reset) begin
        rstate <= ridle;
        rcount <= 0;
        rindex <= 0;
        rxdata <= 0;
    end else if (tick_16x) begin
        case (rstate)
            ridle : begin
                rindex <= 0;
                rcount <= 0;
                rxdata <= 0;
                
                if (rx_sync2 == 1'b0)
                    rstate <= rwait; 
                else
                    rstate <= ridle;
            end
            
            rwait: begin
                if (rcount == 7) begin    // middle of start bit
                    rcount <= 0;
                    rstate <= recv;
                end else begin
                    rcount <= rcount + 1;
                    rstate <= rwait;
                end
            end
            
            recv: begin
                // Sample exactly at the center of the bit
                if (rcount == 7) s1 <= rx_sync2;
                if (rcount == 8) s2 <= rx_sync2;
                if (rcount == 9) s3 <= rx_sync2;
                
                if (rcount == 15) begin
                    rcount <= 0;
                    rxdata <= {voted_bit, rxdata[9:1]};
                    
                    if (rindex == 9) begin
                        rstate <= ridle;
                    end else begin
                        rindex <= rindex + 1;
                        rstate <= recv;
                    end
                end else begin
                    rcount <= rcount + 1;
                    rstate <= recv;
                end
            end
            default : rstate <= ridle;
        endcase
    end 
 end  
 
 assign rxdone = (rstate == recv && rindex == 9 && rcount == 15 && tick_16x) ? 1'b1 : 1'b0;        
 assign rxout = rxdata[8:1];
 
endmodule