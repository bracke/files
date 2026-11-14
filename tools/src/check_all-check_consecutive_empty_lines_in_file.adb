separate (Check_All)
   procedure Check_Consecutive_Empty_Lines_In_File (Path : String) is
      Content     : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Empty_Run   : Natural := 0;

      procedure Check_Line (Raw : String; Number : Positive) is
      begin
         if Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both) = "" then
            Empty_Run := Empty_Run + 1;
            if Empty_Run > 1 then
               Report (Path & ":" & Natural'Image (Number) & ": multiple consecutive empty lines");
            end if;
         else
            Empty_Run := 0;
         end if;
      end Check_Line;
   begin
      For_Each_Line (Content, Check_Line'Access);
   end Check_Consecutive_Empty_Lines_In_File;
