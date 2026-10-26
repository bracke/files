separate (Files_Suite.Operations)
   --  A window that closes ends its history: an original a paste replaced,
   --  kept hidden only so Undo could put it back, goes to the system trash
   --  under its own name instead of staying hidden in its folder.
   procedure Test_Release_History_Trashes_Originals (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings    : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Trash_Home  : constant String := Root & "_release_history_xdg";
      Src_Dir     : constant String := Join (Root, "release-src");
      Dest_Dir    : constant String := Join (Root, "release-dest");
      Dest        : constant String := Join (Dest_Dir, "report.txt");
      Actions     : Files.Paste.Resolved_Action_Vectors.Vector;
      Model       : Files.Model.Window_Model;
      Step        : Files.Operations.Operation_Result;
      Environment : Files_Suite.Support.Environment_Guard;
      In_Trash    : Boolean := False;
   begin
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (Join (Src_Dir, "report.txt"), "new");
      Write_File (Dest, "old");
      Actions.Append
        (Files.Paste.Resolved_Action'
           (Source_Path => To_Unbounded_String (Join (Src_Dir, "report.txt")),
            Dest_Path   => To_Unbounded_String (Dest),
            Skip        => False,
            Replaced    => True));
      Files.Model.Initialize
        (Model, Dest_Dir, Files.File_System.Load_Directory (Dest_Dir, Settings).Items, Root);
      Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 8);
      Files_Suite.Support.Assert_Equal (Step.Status, Files.Operations.Operation_Success, "the replacing paste runs");
      Assert (Files.Model.Undo_Available (Model), "and can be undone");

      Files.Operations.Release_History (Model);
      Assert (not Files.Model.Undo_Available (Model), "the history ends");
      for Item of Files.File_System.Load_Directory (Files.File_System.Trash_Files_Directory, Settings).Items loop
         In_Trash := In_Trash
           or else (Ada.Strings.Fixed.Index (To_String (Item.Name), "report") > 0
                    and then File_Has_Bytes (To_String (Item.Full_Path), "old"));
      end loop;
      Assert (In_Trash, "the replaced original is in the trash");
      for Item of Files.File_System.Load_Directory (Dest_Dir, Settings).Items loop
         Assert (To_String (Item.Name) = "report.txt", "nothing else stays in its folder: " & To_String (Item.Name));
      end loop;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Reset_Root;
   end Test_Release_History_Trashes_Originals;
