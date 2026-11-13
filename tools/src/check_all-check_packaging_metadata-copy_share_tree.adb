separate (Check_All.Check_Packaging_Metadata)
   procedure Copy_Share_Tree
     (From_Path : String;
      To_Path   : String)
   is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      if not Project_Tools.Files.Directory_Exists (From_Path) then
         return;
      end if;

      Ada.Directories.Create_Path (To_Path);
      Ada.Directories.Start_Search
        (Search,
         Directory => From_Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => True,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name        : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Source_Path : constant String := Ada.Directories.Full_Name (Dir_Entry);
            Target_Path : constant String := To_Path & "/" & Name;
         begin
            if Name = "." or else Name = ".." then
               null;
            elsif Ada.Directories.Kind (Dir_Entry) = Ada.Directories.Directory then
               Copy_Share_Tree (Source_Path, Target_Path);
            else
               Ada.Directories.Copy_File (Source_Path, Target_Path);
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
   end Copy_Share_Tree;
