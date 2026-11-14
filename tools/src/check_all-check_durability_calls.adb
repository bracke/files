separate (Check_All)
   procedure Check_Durability_Calls is
   begin
      for Item of Project_Tools.Files.List_Tree (Root & "/src", "*.ad?", Generated_Directories) loop
         declare
            Path  : constant String := To_String (Item);
            Lower : constant String :=
              Ada.Characters.Handling.To_Lower
                (Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Blank_Strings => True));
         begin
            if Ada.Directories.Simple_Name (Path) /= "files-durability.adb"
              and then Ada.Strings.Fixed.Index (Lower, "hostkit.durability.sync_") > 0
            then
               Put_Line
                 (Standard_Error,
                  Path & ": flushes with Hostkit.Durability.Sync_*; use Files.Durability, which tests can fail");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end;
      end loop;
   end Check_Durability_Calls;
