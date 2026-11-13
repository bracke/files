separate (Check_All)
   procedure Check_Consecutive_Empty_Lines_In_File (Path : String) is
      Content     : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Line_Number : Natural := 1;
      Line_Start  : Positive := Content'First;
      Empty_Run   : Natural := 0;

      procedure Check_Line (Raw : String) is
      begin
         if Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both) = "" then
            Empty_Run := Empty_Run + 1;
            if Empty_Run > 1 then
               Put_Line
                 (Standard_Error,
                  Path & ":" & Natural'Image (Line_Number) & ": multiple consecutive empty lines");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         else
            Empty_Run := 0;
         end if;
      end Check_Line;
   begin
      if Content = "" then
         return;
      end if;

      for Index in Content'Range loop
         if Content (Index) = ASCII.LF then
            Check_Line (Content (Line_Start .. Index - 1));
            Line_Number := Line_Number + 1;
            Line_Start := Index + 1;
         end if;
      end loop;

      if Line_Start <= Content'Last then
         Check_Line (Content (Line_Start .. Content'Last));
      end if;
   end Check_Consecutive_Empty_Lines_In_File;
