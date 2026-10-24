separate (Files_Suite.Operations)
   procedure Test_Thumbnail_Cache_Is_Per_User (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      Browsed    : constant String := Join (Root, "pictures");
      Cache_Home : constant String := Join (Root, "cache-home");

      --  The variable this host keeps its per-user cache root in, and what the
      --  resolver should make of it once XDG_CACHE_HOME is out of the way.
      Host_Variable : constant String :=
        (if Hostkit.Host.Current = Hostkit.Host.Windows then "LOCALAPPDATA" else "HOME");
      Host_Cache_Root : constant String :=
        (case Hostkit.Host.Current is
            when Hostkit.Host.Windows => Cache_Home,
            when Hostkit.Host.MacOS   => Join (Cache_Home, "Library/Caches"),
            when others               => Join (Cache_Home, ".cache"));

      Had_Xdg   : constant Boolean := Ada.Environment_Variables.Exists ("XDG_CACHE_HOME");
      Had_Host  : constant Boolean := Ada.Environment_Variables.Exists (Host_Variable);
      Old_Xdg   : Unbounded_String;
      Old_Host  : Unbounded_String;

      procedure Restore is
      begin
         if Had_Xdg then
            Ada.Environment_Variables.Set ("XDG_CACHE_HOME", To_String (Old_Xdg));
         else
            Ada.Environment_Variables.Clear ("XDG_CACHE_HOME");
         end if;

         if Had_Host then
            Ada.Environment_Variables.Set (Host_Variable, To_String (Old_Host));
         else
            Ada.Environment_Variables.Clear (Host_Variable);
         end if;
      end Restore;

      function Cache_Directory return String is
        (Files.File_System.Default_Thumbnail_Cache_Directory (Browsed));
   begin
      if Had_Xdg then
         Old_Xdg := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_CACHE_HOME"));
      end if;

      if Had_Host then
         Old_Host := To_Unbounded_String (Ada.Environment_Variables.Value (Host_Variable));
      end if;

      Ada.Environment_Variables.Set ("XDG_CACHE_HOME", Cache_Home);
      Assert
        (Cache_Directory = Join (Join (Cache_Home, "files"), "thumbnails"),
         "an explicit XDG_CACHE_HOME is honoured on every host, got " & Cache_Directory);

      Ada.Environment_Variables.Set (Host_Variable, Cache_Home);
      Ada.Environment_Variables.Set ("XDG_CACHE_HOME", "relative-cache-home");
      Assert
        (GNAT.OS_Lib.Is_Absolute_Path (Cache_Directory)
         and then Cache_Directory /=
           Join (Join ("relative-cache-home", "files"), "thumbnails"),
         "a relative XDG_CACHE_HOME cannot redirect thumbnails into the process directory");

      Ada.Environment_Variables.Clear ("XDG_CACHE_HOME");
      Assert
        (Cache_Directory = Join (Join (Host_Cache_Root, "files"), "thumbnails"),
         "without XDG_CACHE_HOME the cache follows this host's convention, got " & Cache_Directory);

      Assert
        (Cache_Directory'Length < Browsed'Length
           or else Cache_Directory (Cache_Directory'First .. Cache_Directory'First + Browsed'Length - 1)
                     /= Browsed,
         "the thumbnail cache is never written into the folder being browsed, got " & Cache_Directory);

      Restore;
   exception
      when others =>
         Restore;
         raise;
   end Test_Thumbnail_Cache_Is_Per_User;
