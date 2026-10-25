separate (Files.Operations)
--  Full paths of every entry directly inside Directory (hidden entries
--  included). Used as the "already exists" set for conflict detection and for
--  rename uniquification, so a renamed paste avoids any existing name, not
--  just the colliding one. Falls back to an empty set when the directory
--  cannot be scanned; Execute_Drop_Import then still refuses to clobber.
function Existing_Destination_Paths
  (Directory : String)
   return Files.Types.String_Vectors.Vector
is
   Max_Destination_Entries : constant Natural := 100_000;
   Result : Files.Types.String_Vectors.Vector;
   Search : Ada.Directories.Search_Type;
   Entry_Value : Ada.Directories.Directory_Entry_Type;
   Started : Boolean := False;
   Count : Natural := 0;
begin
   Ada.Directories.Start_Search
     (Search    => Search,
      Directory => Directory,
      Pattern   => "",
      Filter    => [others => True]);
   Started := True;
   while Ada.Directories.More_Entries (Search) loop
      if Count = Max_Destination_Entries then
         Ada.Directories.End_Search (Search);
         Started := False;
         return Files.Types.String_Vectors.Empty_Vector;
      end if;
      Ada.Directories.Get_Next_Entry (Search, Entry_Value);
      declare
         Name : constant String := Ada.Directories.Simple_Name (Entry_Value);
      begin
         if Name /= "." and then Name /= ".." then
            Result.Append (To_Unbounded_String (Files.Paste.Desired_Path (Directory, Name)));
            Count := Count + 1;
         end if;
      end;
   end loop;
   Ada.Directories.End_Search (Search);
   Started := False;
   return Result;
exception
   when others =>
      if Started then
         begin
            Ada.Directories.End_Search (Search);
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.Operations.Transfer");
         end;
      end if;
      return Files.Types.String_Vectors.Empty_Vector;
end Existing_Destination_Paths;
