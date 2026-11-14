separate (Check_All)
   procedure Check_Project_Text_Files is
   begin
      for Item of Project_Text_Files loop
         declare
            Path : constant String := To_String (Item);
         begin
            Check_Line_Lengths_In_File (Path);
            Check_Consecutive_Empty_Lines_In_File (Path);
            --  A catalog's value may end in a blank, and C sources are not
            --  held to it either.
            if Is_Whitespace_Checked_File (Ada.Directories.Simple_Name (Path)) then
               Check_Whitespace_In_File (Path);
            end if;
         end;
      end loop;
   end Check_Project_Text_Files;
