separate (Check_All)
   procedure Check_Host_Questions is
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
         begin
            if Ada.Strings.Fixed.Index (Code, "Alire_Host_OS") > 0 then
               Ada.Directories.End_Search (Search);
               Put_Line (Standard_Error, Path & ": asks the build's OS string; use Hostkit.Host.Current");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
   end Check_Host_Questions;
