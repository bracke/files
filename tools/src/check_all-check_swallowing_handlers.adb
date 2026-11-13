separate (Check_All)
   procedure Check_Swallowing_Handlers is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;

      procedure Check_File (Path : String) is separate;
   begin
      Ada.Directories.Start_Search
        (Search, Root & "/src", "*.ad?", [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         if Ada.Directories.Simple_Name (Item)
           not in "files-diagnostics.ads" | "files-diagnostics.adb" | "files-environment.ads" | "files-environment.adb"
         then
            Check_File (Ada.Directories.Full_Name (Item));
         end if;
      end loop;
      Ada.Directories.End_Search (Search);
   end Check_Swallowing_Handlers;
