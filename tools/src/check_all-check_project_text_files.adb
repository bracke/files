separate (Check_All)
   procedure Check_Project_Text_Files is
   begin
      for Item of Project_Text_Files loop
         declare
            Path : constant String := To_String (Item);
         begin
            --  A workflow's lines are shell and URLs, not code: held to the
            --  whitespace and blank-line rules but not to a line length.
            if not Ends_With (Path, ".yml") then
               Check_Line_Lengths_In_File (Path);
            end if;
            Check_Consecutive_Empty_Lines_In_File (Path);
            --  A catalog's value may end in a blank, and C sources are not
            --  held to it either.
            if Is_Whitespace_Checked_File (Ada.Directories.Simple_Name (Path)) then
               Check_Whitespace_In_File (Path);
            end if;
            --  Alire's TOML reader rejects a manifest with a non-ASCII byte
            --  (an em-dash in a description) on CI, and every crate pinning
            --  this one turns red with it.
            if Ends_With (Path, ".toml") then
               Check_Ascii_Only_In_File (Path);
            end if;
         end;
      end loop;
   end Check_Project_Text_Files;
