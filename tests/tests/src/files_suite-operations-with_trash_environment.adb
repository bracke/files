separate (Files_Suite.Operations)
   procedure With_Trash_Environment (Check : not null access procedure) is
      Trash_Home   : constant String := Root & "_xdg_data";
      Mac_Home     : constant String := Root & "_mac_home";
      --  Restores what Check changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "HOME");
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Check.all;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Project_Tools.Files.Delete_Tree (Mac_Home);
   end With_Trash_Environment;
