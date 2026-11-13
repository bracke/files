separate (Check_All)
   procedure Check_Line_Lengths_In_File (Path : String) is
      Content : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Line    : Natural := 1;
      Column  : Natural := 0;
   begin
      for Char of Content loop
         if Char = ASCII.LF then
            Line := Line + 1;
            Column := 0;
         --  Characters, not bytes, as the compiler's -gnatyM counts under
         --  -gnatW8: a UTF-8 continuation byte (2#10xx_xxxx#) belongs to the
         --  character its lead byte began.
         elsif Character'Pos (Char) not in 16#80# .. 16#BF# then
            Column := Column + 1;
            if Column > Max_Line_Length then
               Put_Line
                 (Standard_Error,
                  Path & ":" & Natural'Image (Line) & ": line exceeds"
                  & Natural'Image (Max_Line_Length) & " characters");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end if;
      end loop;
   end Check_Line_Lengths_In_File;
