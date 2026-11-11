separate (Files.File_System.Thumbnails)
function List_Thumbnail_Cache (Cache_Directory : String) return Cache_Index is
   Result : Cache_Index;
   Count  : Natural := 0;
   Capped : Boolean := False;

   procedure Collect (Name : String; Kind : Hostkit.Fs.Entry_Kind; Stop : in out Boolean) is
      use type Hostkit.Fs.Entry_Kind;
   begin
      if Kind /= Hostkit.Fs.Ordinary_File_Entry then
         return;
      elsif Count = Max_Thumbnail_Cache_Entries then
         Capped := True;
         Stop := True;
         return;
      end if;
      Result.Names.Include (Name);
      Count := Count + 1;
   end Collect;
begin
   Result.Listed := True;

   if Cache_Directory = "" or else not Files.Fs_Primitives.Directory_Exists (Cache_Directory) then
      return Result;
   end if;

   Files.Fs_Primitives.For_Each_Listed (Cache_Directory, Collect'Access);
   if Capped then
      Result.Listed := False;
      Result.Names.Clear;
   end if;
   return Result;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
      return (Listed => False, Names => Thumbnail_Name_Sets.Empty_Set, Generate => True, Shared => False);
end List_Thumbnail_Cache;
