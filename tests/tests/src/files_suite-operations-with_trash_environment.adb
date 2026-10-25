separate (Files_Suite.Operations)
   procedure With_Trash_Environment (Check : not null access procedure) is
      Trash_Home   : constant String := Root & "_xdg_data";
      Mac_Home     : constant String := Root & "_mac_home";
      --  Restores what Check changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;

      --  Remove both homes, if present.
      procedure Clean is
      begin
         Project_Tools.Files.Delete_Tree (Trash_Home);
         Project_Tools.Files.Delete_Tree (Mac_Home);
      end Clean;
   begin
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "HOME");
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");

      Reset_Root;
      --  Both homes sit beside Root, not under it, so Reset_Root leaves them:
      --  clear what an earlier, failed run left before Check sees it.
      Clean;
      Check.all;
      Clean;
   exception
      when others =>
         Clean;
         raise;
   end With_Trash_Environment;
