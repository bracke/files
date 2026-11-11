separate (Files_Suite.Operations)
   procedure Test_Folder_Count_Honours_Hidden (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Box : constant String := Join (Root, "box");

      function Count_Of (Show_Hidden : Boolean) return String is
        (Files_Suite.Support.Describe
           (Files.File_System.Extra_Info_Of (Box, Files.Types.Directory_Item, "inode/directory", Show_Hidden)));
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Box, ".cache"));
      Write_File (Join (Box, "shown.txt"));
      Write_File (Join (Box, ".hidden"));
      Ada.Directories.Create_Path (Join (Box, "folder"));

      Files_Suite.Support.Assert_Equal
        (Count_Of (Show_Hidden => True), "directory.count|4", "with hidden files shown, every entry counts");
      Files_Suite.Support.Assert_Equal
        (Count_Of (Show_Hidden => False),
         "directory.count|2",
         "with hidden files not shown, hidden entries do not count");
   end Test_Folder_Count_Honours_Hidden;
