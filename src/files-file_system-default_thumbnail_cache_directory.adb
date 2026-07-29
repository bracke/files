separate (Files.File_System)
   function Default_Thumbnail_Cache_Directory
     (Fallback_Directory : String)
      return String
   is
      Xdg_Cache : constant String := Safe_Environment_Value ("XDG_CACHE_HOME");
      Home      : constant String := Safe_Environment_Value ("HOME");
   begin
      if Xdg_Cache /= "" then
         return Join_Path (Join_Path (Xdg_Cache, "files"), "thumbnails");
      elsif Home /= "" then
         return Join_Path (Join_Path (Join_Path (Home, ".cache"), "files"), "thumbnails");
      else
         return Join_Path (Fallback_Directory, ".files-thumbnails");
      end if;
   end Default_Thumbnail_Cache_Directory;
