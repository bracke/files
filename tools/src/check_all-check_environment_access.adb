separate (Check_All)
   procedure Check_Environment_Access is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
   begin
      Ada.Directories.Start_Search
        (Search, Root & "/src", "*.ad?", [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Path : constant String := Ada.Directories.Full_Name (Item);
            Code : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
            Lower : constant String := Ada.Characters.Handling.To_Lower (Code);
         begin
            --  Ada's own, Hostkit's (which Files.Environment wraps), a C
            --  getenv bound by hand, GNAT's command-line environment.
            if Ada.Directories.Simple_Name (Path) not in "files-environment.adb" | "files-environment.ads"
              and then (Ada.Strings.Fixed.Index (Lower, "ada.environment_variables") > 0
                        or else Ada.Strings.Fixed.Index (Lower, "hostkit.environment") > 0
                        or else Ada.Strings.Fixed.Index (Lower, "getenv") > 0
                        or else Ada.Strings.Fixed.Index (Lower, "environment_value") > 0
                        or else Ada.Strings.Fixed.Index (Lower, "command_line.environment") > 0)
            then
               Ada.Directories.End_Search (Search);
               Put_Line (Standard_Error, Path & ": reads the environment directly; use Files.Environment");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
   end Check_Environment_Access;
