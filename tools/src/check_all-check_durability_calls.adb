separate (Check_All)
   procedure Check_Durability_Calls is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
   begin
      Ada.Directories.Start_Search
        (Search, Root & "/src", "*.ad?", [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Path  : constant String := Ada.Directories.Full_Name (Item);
            Lower : constant String :=
              Ada.Characters.Handling.To_Lower
                (Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Blank_Strings => True));
         begin
            if Ada.Directories.Simple_Name (Item) /= "files-durability.adb"
              and then Ada.Strings.Fixed.Index (Lower, "hostkit.durability.sync_") > 0
            then
               Ada.Directories.End_Search (Search);
               Put_Line
                 (Standard_Error,
                  Path & ": flushes with Hostkit.Durability.Sync_*; use Files.Durability, which tests can fail");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
   end Check_Durability_Calls;
