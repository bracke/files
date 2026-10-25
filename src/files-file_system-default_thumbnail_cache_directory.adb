separate (Files.File_System)
function Default_Thumbnail_Cache_Directory
  (Fallback_Directory : String)
   return String
is
   Raw_Xdg_Cache : constant String := Safe_Environment_Value ("XDG_CACHE_HOME");
   Xdg_Cache : constant String :=
     (if GNAT.OS_Lib.Is_Absolute_Path (Raw_Xdg_Cache) then Raw_Xdg_Cache
      else "");

   function In_Cache_Root (Root : String) return String is
     (Join_Path (Join_Path (Root, "files"), "thumbnails"));

   --  Where this host keeps a per-user cache is Hostkit's question --
   --  LOCALAPPDATA rather than the roaming APPDATA, ~/Library/Caches rather
   --  than Application Support, $XDG_CACHE_HOME or ~/.cache -- and it used to
   --  be spelled out here.
   --
   --  XDG_CACHE_HOME is checked first, before asking, because honouring it on
   --  every host is this application's policy rather than a host fact: macOS
   --  and Windows do not read it, and Hostkit says what the host does. A user
   --  who exported it meant it.
   function Host_Cache_Root return String is
   begin
      if Xdg_Cache /= "" then
         return Xdg_Cache;
      end if;

      declare
         Root : constant String := Hostkit.Fs.Cache_Directory;
      begin
         return
           (if GNAT.OS_Lib.Is_Absolute_Path (Root) then Root else "");
      end;
   end Host_Cache_Root;

   Cache_Root : constant String := Host_Cache_Root;
begin
   if Cache_Root /= "" then
      return In_Cache_Root (Cache_Root);
   end if;

   --  Nothing to go on. Writing the cache into the directory being browsed
   --  is the last resort it has always been -- it is somewhere writable and
   --  it is where the images are -- but it leaves a hidden folder behind in
   --  the user's own data, so it is reached only when the host will not say
   --  where its cache belongs.
   return Join_Path (Fallback_Directory, ".files-thumbnails");
end Default_Thumbnail_Cache_Directory;
