separate (Files.File_System.Directory)
   function Thumbnail_For_Item
     (Full_Path       : String;
      Kind            : Files.Types.Item_Kind;
      Filetype        : String;
      Name            : String;
      Icon_Id         : String;
      Cache_Directory : String;
      Thumbnail_Path  : String)
      return Cached_Thumbnail
   is
      Loaded : Cached_Thumbnail := Load_Cached_Thumbnail (Thumbnail_Path);
   begin
      if Loaded.Loaded
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
