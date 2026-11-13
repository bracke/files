separate (Check_All)
   procedure Check_Whitespace_In_File (Path : String) is
      Content     : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Line_Number : Natural := 1;
      Line_Start  : Positive := Content'First;

      procedure Fail (Message : String) is
      begin
         Put_Line
           (Standard_Error,
            Path & ":" & Natural'Image (Line_Number) & ": " & Message);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Fail;

      procedure Check_Line (Raw : String) is
      begin
         if Raw'Length = 0 then
            return;
         end if;

         for Character_Value of Raw loop
            if Character_Value = ASCII.HT then
               Fail ("tab character is not allowed");
            end if;
         end loop;

         if Raw (Raw'Last) = ' ' or else Raw (Raw'Last) = ASCII.HT then
            Fail ("trailing whitespace is not allowed");
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
   end Check_Whitespace_In_File;
