separate (Files.File_System)
function Thumbnail_For_Item
  (Full_Path       : String;
   Kind            : Files.Types.Item_Kind;
   Filetype        : String;
   Name            : String;
   Icon_Id         : String;
   Cache_Directory : String;
   Thumbnail_Path  : String;
   Cached          : Cache_Index)
   return Cached_Thumbnail
is
   --  With a listing in hand this costs no syscall at all. Without one it is
   --  the stat it always was.
   --
   --  A thumbnail another process writes while this listing runs is missed
   --  and picked up by the next one, which is what a stat per file bought
   --  and is not worth 20,000 of them.
   Present : constant Boolean :=
     (if Cached.Listed
      then Thumbnail_Path /= ""
           and then Cache_Holds (Cached, Ada.Directories.Simple_Name (Thumbnail_Path))
      else True);

   Loaded : Cached_Thumbnail :=
     (if Present
      then Load_Cached_Thumbnail (Thumbnail_Path)
      else (Loaded => False, Width => 0, Height => 0,
            Pixels => Files.Types.Byte_Vectors.Empty_Vector));
begin
   if Loaded.Loaded
     or else not Cached.Generate
     or else not Should_Auto_Generate_Thumbnail (Kind, Filetype, Name, Icon_Id)
   then
      return Loaded;
   end if;

   declare
      Generated : constant Thumbnail_Result :=
        Generate_Thumbnail (Full_Path, Cache_Directory);
   begin
      if Generated.Status = Thumbnail_Generated then
         Loaded := Load_Cached_Thumbnail (To_String (Generated.Thumbnail_Path));
      end if;
   end;

   return Loaded;
exception
   when others =>
      return Loaded;
end Thumbnail_For_Item;
