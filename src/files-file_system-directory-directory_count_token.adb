separate (Files.File_System.Directory)
   function Directory_Count_Token (Path : String) return String is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Count     : Natural := 0;
      Started   : Boolean := False;
   begin
      if not Files.Fs.Directory_Exists (Path)
      then
         return "";
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
            Ada.Directories.Directory     => True,
            Ada.Directories.Special_File  => True]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
         begin
            if Name /= "." and then Name /= ".." then
               Count := Count + 1;
            end if;
         end;
      end loop;

      Safe_End_Search (Search, Started);
      return "directory.count|" & Natural_Text (Count);
   exception
      when others =>
         Safe_End_Search (Search, Started);
         return "";
   end Directory_Count_Token;
