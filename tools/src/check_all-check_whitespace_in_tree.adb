separate (Check_All)
   procedure Check_Whitespace_In_Tree (Path : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      if Project_Tools.Files.File_Exists (Path) then
         Check_Whitespace_In_File (Path);
         return;
      elsif not Project_Tools.Files.Directory_Exists (Path) then
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
            if Name /= "." and then Name /= ".." then
               case Ada.Directories.Kind (Dir_Entry) is
                  when Ada.Directories.Ordinary_File =>
                     if Is_Whitespace_Checked_File (Name) then
                        Check_Whitespace_In_File (Full);
                     end if;
                  when Ada.Directories.Directory =>
                     if not Is_Generated_Directory_Name (Name) then
                        Check_Whitespace_In_Tree (Full);
                     end if;
                  when Ada.Directories.Special_File =>
                     null;
               end case;
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
   end Check_Whitespace_In_Tree;
