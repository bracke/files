separate (Files.File_System)
function Index_Thumbnail_Cache (Cache_Directory : String) return Cache_Index is
   use type Ada.Calendar.Time;
   Stamp : Ada.Calendar.Time;
   Index : Cache_Index;
   --  The remembered listing, answering for the cache in place.
   Shared : constant Cache_Index :=
     (Listed => True, Names => Thumbnail_Name_Sets.Empty_Set, Generate => True, Shared => True);
begin
   if Cache_Directory = "" or else not Files.Fs.Directory_Exists (Cache_Directory) then
      return List_Thumbnail_Cache (Cache_Directory);
   end if;
   Stamp := Ada.Directories.Modification_Time (Cache_Directory);
   if Ada.Calendar.Clock - Stamp < 2.0 then
      return List_Thumbnail_Cache (Cache_Directory);
   end if;
   if Cache_Index_Memo.Holds (Cache_Directory, Stamp) then
      return Shared;
   end if;
   Index := List_Thumbnail_Cache (Cache_Directory);
   if Index.Listed then
      Cache_Index_Memo.Keep (Cache_Directory, Stamp, Index);
   end if;
   return Index;
exception
   when others =>
      return List_Thumbnail_Cache (Cache_Directory);
end Index_Thumbnail_Cache;
