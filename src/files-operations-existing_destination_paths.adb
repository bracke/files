separate (Files.Operations)
   function Existing_Destination_Paths
     (Directory : String)
      return Files.Types.String_Vectors.Vector
   is
      Result : Files.Types.String_Vectors.Vector;
      Search : Ada.Directories.Search_Type;
      Entry_Value : Ada.Directories.Directory_Entry_Type;
   begin
      Ada.Directories.Start_Search
        (Search    => Search,
         Directory => Directory,
         Pattern   => "",
         Filter    => [others => True]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Entry_Value);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Entry_Value);
         begin
            if Name /= "." and then Name /= ".." then
               Result.Append (To_Unbounded_String (Files.Paste.Desired_Path (Directory, Name)));
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
      return Result;
   exception
      when others =>
         return Files.Types.String_Vectors.Empty_Vector;
   end Existing_Destination_Paths;
