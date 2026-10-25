separate (Files.File_System)
function Trash_Location_For_Environment return Trash_Location is
   Xdg_Data_Home : constant String := Safe_Environment_Value ("XDG_DATA_HOME");
   Home          : constant String := Safe_Environment_Value ("HOME");

   Result : Trash_Location;
begin
   --  The desktop's own trash: asked for explicitly. Both leave Base empty --
   --  the shell owns the location and there is no path of ours to hand back.
   if Environment_Equals ("FILES_TRASH_BACKEND", "windows") then
      return (Backend => Trash_Windows_Recycle_Bin, Base => Null_Unbounded_String);
   elsif Environment_Equals ("FILES_TRASH_BACKEND", "macos") then
      return (Backend => Trash_Macos_Native, Base => Null_Unbounded_String);
   end if;

   --  The freedesktop base directories are absolute paths.  Treat a
   --  malformed environment value as unset instead of making trash
   --  operations relative to the file manager's process directory.
   if Xdg_Data_Home /= "" and then GNAT.OS_Lib.Is_Absolute_Path (Xdg_Data_Home) then
      Result :=
        (Backend => Trash_Xdg_Data_Home,
         Base    => To_Unbounded_String (Join_Path (Xdg_Data_Home, "Trash")));
   elsif Home /= "" and then GNAT.OS_Lib.Is_Absolute_Path (Home) then
      --  ~/.Trash is the macOS layout (no info files), taken only on macOS
      --  or when asked for: on Linux a stray ~/.Trash is just a folder, and
      --  trashing into it would leave items nothing can restore.
      if Environment_Equals ("FILES_TRASH_BACKEND", "macos-home")
        or else (Files_Config.Alire_Host_OS = "macos"
                 and then not Environment_Equals ("FILES_TRASH_BACKEND", "xdg")
                 and then Ada.Directories.Exists (Join_Path (Home, ".Trash")))
      then
         Result :=
           (Backend => Trash_Macos_Home,
            Base    => To_Unbounded_String (Join_Path (Home, ".Trash")));
      else
         Result :=
           (Backend => Trash_Home_Data,
            Base    =>
              To_Unbounded_String
                (Join_Path (Join_Path (Join_Path (Home, ".local"), "share"), "Trash")));
      end if;
   end if;

   --  Windows has no HOME/XDG trash, so the shell Recycle Bin is the default
   --  there; "xdg" (or "macos-home") forces that implementation on any host, which is
   --  what lets it be exercised where it is not the default. Only the backend
   --  changes -- the base keeps whatever the layout above worked out, which is
   --  what the previous pair of functions did.
   if Files_Config.Alire_Host_OS = "windows"
     and then not Environment_Equals ("FILES_TRASH_BACKEND", "xdg")
     and then not Environment_Equals ("FILES_TRASH_BACKEND", "macos-home")
   then
      Result.Backend := Trash_Windows_Recycle_Bin;
   end if;

   return Result;
end Trash_Location_For_Environment;
