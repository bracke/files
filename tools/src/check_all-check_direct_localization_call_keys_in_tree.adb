separate (Check_All)
   procedure Check_Direct_Localization_Call_Keys_In_Tree (Path : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      if not Project_Tools.Files.Directory_Exists (Path) then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => True,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Name = "." or else Name = ".." then
               null;
            elsif Ada.Directories.Kind (Dir_Entry) = Ada.Directories.Directory then
               if not Is_Generated_Directory_Name (Name) then
                  Check_Direct_Localization_Call_Keys_In_Tree (Full);
               end if;
            elsif Name'Length >= 4
              and then (Name (Name'Last - 3 .. Name'Last) = ".ads"
                        or else Name (Name'Last - 3 .. Name'Last) = ".adb")
            then
               Check_Direct_Localization_Call_Keys_In_File (Full);
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_Direct_Localization_Call_Keys_In_Tree;
