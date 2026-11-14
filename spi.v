`timescale 1ns / 1ps


module spi #(parameter sys_clk_F = 50_000_000,
             parameter sclk_F = 1000_000,
             parameter D_w = 12)
(
input sys_clk,reset,start,
input [15:0] clk_div,
input [D_w-1:0] din ,
input cpol,
input cpha,
input miso,
output reg [D_w -1 : 0] rx,         
output reg cs, mosi,done,
output reg sclk
    );
    
reg miso_sync1, miso_sync2;

always @(posedge sys_clk) 
begin
    if (reset)
     begin
        miso_sync1 <= 1'b0;
        miso_sync2 <= 1'b0;
    end else begin
        miso_sync1 <= miso;
        miso_sync2 <= miso_sync1; 
    end
end
    

 integer count = 0;
 wire spi_tick = (count == clk_div);

    always @(posedge sys_clk) begin
        if (reset) count <= 0;
        else if (spi_tick) count <= 0;
        else count <= count + 1;
    end
 
 //////////// SPI FSM
 
 parameter idle =0, start_tx=1, send = 2, end_tx = 3;
 reg [1:0] state = idle ;
 reg phase;
 
 reg [D_w-1:0] temp, temp_rx;
 integer bit_count;
 
 always @ (posedge sys_clk)
 begin
    if (reset)
      begin
        state <= idle;
        mosi <= 0;
        sclk <= cpol;
        cs <= 1;
        phase <= 1'b0;
        done <= 0;
        bit_count <= D_w - 1;
        rx <= 0;
        temp_rx <=0;
       end
      else if (spi_tick) begin // Acts exactly like your old 'posedge sclk'
    
        case (state)
            idle : begin
                cs <= 1;
                mosi <= 0;
                sclk <= cpol;
                done <= 0;
                phase <= 1'b0;
                bit_count <= D_w - 1;
                
                if (start)
                    state <= start_tx;
                else
                    state <= idle;
            end  
            
            start_tx : begin
                cs <= 0;
                temp <= din; 
                state <= send;
                
                // Mode 0/1: Data must be placed on MOSI before the first clock edge
                if (cpha == 1'b0) begin
                    mosi <= din[D_w - 1];
                end
            end 
            
            send : begin
                phase <= ~phase;
                sclk <= ~sclk;   
                
                if (cpha == 1'b0) begin
                    // Mode 0/1: Sample MISO on Leading (0), Shift MOSI on Trailing (1)
                    if (phase == 1'b0) begin
                        temp_rx <= {temp_rx[D_w-2: 0], miso_sync2};
                    end else begin
                        bit_count <= bit_count - 1;
                        mosi <= temp[bit_count - 1]; 
                        if (bit_count == 0) state <= end_tx;
                    end
                end else begin
                    // Mode 2/3: Shift MOSI on Leading (0), Sample MISO on Trailing (1)
                    if (phase == 1'b0) begin
                        mosi <= temp[bit_count];
                    end else begin
                        temp_rx <= {temp_rx[D_w-2: 0], miso_sync2};
                        bit_count <= bit_count - 1;
                        if (bit_count == 0) state <= end_tx;
                    end
                end
            end 
            
            end_tx : begin 
                state <= idle;
                done <= 1;
                cs <= 1;
                sclk <= cpol; 
                mosi <= 0;
            end 
            
            default : begin 
                state <= idle;
            end   
        endcase 
        
        rx <= temp_rx;
   end   
 end                 
                       
    
endmodule