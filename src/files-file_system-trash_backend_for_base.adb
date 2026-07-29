separate (Files.File_System)
   function Trash_Backend_For_Base return Trash_Backend is
      Xdg_Data_Home : constant String := Safe_Environment_Value ("XDG_DATA_HOME");
      Home          : constant String := Safe_Environment_Value ("HOME");
   begin
      if Environment_Equals ("FILES_TRASH_BACKEND", "windows") then
         return Trash_Windows_Recycle_Bin;
      elsif Environment_Equals ("FILES_TRASH_BACKEND", "macos") then
         return Trash_Macos_Native;
      elsif Files_Config.Alire_Host_OS = "windows"
        and then not Environment_Equals ("FILES_TRASH_BACKEND", "xdg")
      then
         --  Windows has no HOME/XDG trash; use the shell Recycle Bin by default.
         --  "xdg" forces the freedesktop implementation regardless of host, which
         --  is what lets it be exercised on every platform rather than only where
         --  it happens to be the default.
         return Trash_Windows_Recycle_Bin;
      elsif Xdg_Data_Home /= "" then
         return Trash_Xdg_Data_Home;
      elsif Home /= "" then
         if Ada.Directories.Exists (Join_Path (Home, ".Trash")) then
            return Trash_Macos_Home;
         else
            return Trash_Home_Data;
         end if;
      end if;

      return Trash_Unavailable;
   end Trash_Backend_For_Base;
