separate (Files.File_System)
function List_Thumbnail_Cache (Cache_Directory : String) return Cache_Index is
   Result : Cache_Index;
   Search : Ada.Directories.Search_Type;
   Item   : Ada.Directories.Directory_Entry_Type;
   Started : Boolean := False;
   Count   : Natural := 0;
begin
   Result.Listed := True;

   if Cache_Directory = "" or else not Files.Fs.Directory_Exists (Cache_Directory) then
      return Result;
   end if;

   Ada.Directories.Start_Search
     (Search, Cache_Directory, "*",
      Filter => [Ada.Directories.Ordinary_File => True, others => False]);
   Started := True;

   while Ada.Directories.More_Entries (Search) loop
      if Count = Max_Thumbnail_Cache_Entries then
         Safe_End_Search (Search, Started);
         Result.Listed := False;
         Result.Names.Clear;
         return Result;
      end if;
      Ada.Directories.Get_Next_Entry (Search, Item);
      Result.Names.Include (Ada.Directories.Simple_Name (Item));
      Count := Count + 1;
   end loop;

   Safe_End_Search (Search, Started);
   return Result;
exception
   when others =>
      Safe_End_Search (Search, Started);
      return (Listed => False, Names => Thumbnail_Name_Sets.Empty_Set, Generate => True, Shared => False);
end List_Thumbnail_Cache;
