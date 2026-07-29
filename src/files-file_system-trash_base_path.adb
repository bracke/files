separate (Files.File_System)
   function Trash_Base_Path return String is
      Xdg_Data_Home : constant String := Safe_Environment_Value ("XDG_DATA_HOME");
      Home          : constant String := Safe_Environment_Value ("HOME");
   begin
      if Environment_Equals ("FILES_TRASH_BACKEND", "windows") then
         return "";
      elsif Environment_Equals ("FILES_TRASH_BACKEND", "macos") then
         return "";
      end if;

      if Xdg_Data_Home /= "" then
         return Join_Path (Xdg_Data_Home, "Trash");
      elsif Home /= "" then
         if Ada.Directories.Exists (Join_Path (Home, ".Trash")) then
            return Join_Path (Home, ".Trash");
         end if;

         return Join_Path (Join_Path (Join_Path (Home, ".local"), "share"), "Trash");
      end if;

      return "";
   end Trash_Base_Path;
