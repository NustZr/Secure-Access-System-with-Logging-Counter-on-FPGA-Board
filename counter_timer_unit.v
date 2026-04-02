module counter_timer_unit (
input wire clk,              // Clock 20MHz จากบอร์ด
input wire rst_n,            // ปุ่ม Reset ระบบ (Active Low)
input wire error_pulse,      // สัญญาณบอกว่า "รหัสผิด" (รับมาจาก Verification Unit)
input wire reset_counter,    // สัญญาณสั่งล้างค่าการนับ (รับจาก FSM ตอนใส่รหัสถูก หรือตอนหมดเวลาล็อก)
input wire start_timer,      // สัญญาณสั่งเริ่มจับเวลา 10 วินาที (รับมาจาก FSM ตอนเข้าโหมด LOCK)

```
 output reg [2:0] attempt_count, // ส่งค่าจำนวนครั้งที่ผิดไปแสดงผลบน LED (ตามที่ระบุใน Proposal)
output reg max_try_reached,     // สัญญาณเตือนว่า "ผิดครบ 3 ครั้งแล้ว!" ไปยัง FSM
output reg timer_done           // สัญญาณบอก FSM ว่า "ครบ 10 วินาทีแล้ว ปลดล็อกได้"
```

);

```
// ----------------------------------------------------
// ส่วนที่ 1: ตัวนับจำนวนครั้งที่ใส่รหัสผิด (Attempt Counter)
// ----------------------------------------------------
	always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        attempt_count <= 3'd0;
        max_try_reached <= 1'b0;
    end else if (reset_counter) begin
        // ล้างค่าการนับเมื่อได้รับคำสั่ง
			attempt_count <= 3'd0;
        max_try_reached <= 1'b0;
    end else if (error_pulse) begin
        // ถ้ารหัสผิด ให้นับเพิ่มทีละ 1
        if (attempt_count < 3'd3) begin
            attempt_count <= attempt_count + 1'b1;
        end

			// เช็คว่าการผิดครั้งนี้ ทำให้ครบ 3 ครั้งหรือยัง?
        if (attempt_count == 3'd2) begin
            max_try_reached <= 1'b1; // ส่งสัญญาณเตือนให้ระบบไปล็อก
        end
    end
end

	// ----------------------------------------------------
// ส่วนที่ 2: ตัวจับเวลา 10 วินาทีตอนระบบล็อก (10s System Timer)
// ----------------------------------------------------
// บอร์ด Surveyor-6 ใช้ Clock 20MHz แปลว่า 1 วินาที = 20,000,000 รอบ
// 10 วินาที = 200,000,000 รอบ (ต้องใช้ตัวแปรขนาด 28 บิตถึงจะเก็บค่าพอ)

 reg [27:0] delay_counter;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        delay_counter <= 28'd0;
        timer_done <= 1'b0;
    end else begin
        timer_done <= 1'b0; // รีเซ็ตสัญญาณแจ้งเตือนเสมอ

			if (start_timer) begin
            // เริ่มจับเวลา
            if (delay_counter < 28'd200_000_000) begin
                delay_counter <= delay_counter + 1'b1;
            end else begin
                // ครบ 10 วินาทีแล้ว
                timer_done <= 1'b1;      // ยิงสัญญาณปลดล็อกไปที่ FSM
                delay_counter <= 28'd0;  // ล้างค่าเวลาเตรียมพร้อมรอบใหม่
            end
        end else begin

			// ถ้าไม่ได้อยู่ในสถานะ LOCK ให้ล้างค่าเวลาเป็น 0 รอไว้เสมอ
            delay_counter <= 28'd0;
        end
    end
end
```

endmodule