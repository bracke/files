separate (Check_All)
   procedure Check_Ascii_Only_In_File (Path : String) is
      Content : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Line    : Positive := 1;
      --  The line already reported, so a line of several such bytes is one
      --  problem.
      Reported : Natural := 0;
   begin
      for Char of Content loop
         if Char = ASCII.LF then
            Line := Line + 1;
         elsif Character'Pos (Char) > 127 and then Reported /= Line then
            Reported := Line;
            Report (Path & ":" & Positive'Image (Line) & ": a manifest must be ASCII only");
         end if;
      end loop;
   end Check_Ascii_Only_In_File;
