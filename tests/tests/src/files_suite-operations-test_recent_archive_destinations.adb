separate (Files_Suite.Operations)
   procedure Test_Recent_Archive_Destinations (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Puts the working directory back however the test ends.
      Cwd_Guard : Files_Suite.Support.Directory_Guard;
      Settings : Files.Settings.Settings_Model;
      Model : Files.Model.Window_Model;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Archives : Files.File_System.Item_Vectors.Vector;
      Loaded : Files.File_System.Item_Load_Result;
      One : constant String := Join (Root, "one");
      Two : constant String := Join (Root, "two");
      Cwd : constant String := Join (Root, "cwd");
      Zip : constant String := Join (Two, "note.zip");
      Copy_Zip : constant String := Join (One, "copy.zip");
   begin
      for Background in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Path (One);
         Ada.Directories.Create_Path (Two);
         Ada.Directories.Create_Path (Cwd);
         Write_Binary_File (Join (One, "report.txt"), "report bytes");
         Write_Binary_File (Join (Two, "note.txt"), "note bytes");
         Write_Binary_File (Join (Cwd, "keep"), "working directory bytes");
         Settings := Files.Settings.Default_Settings;
         Files.Settings.Note_Recent (Settings, Join (One, "report.txt"));
         Files.Settings.Note_Recent (Settings, Join (Two, "note.txt"));
         Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
         Files.Operations.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Step := Files.Operations.Navigate_Recent (Model, Settings);
         Files.Model.Select_All_Visible (Model);
         Ada.Directories.Set_Directory (Cwd);
         Step := Complete_Operation
           (Model, Settings, Files.Operations.Compress_Selected (Model, Settings, Files.Operations.Zip_Archive));
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operations.Operation_Success,
            "Recent compression publishes beside the first selected source and preserves the complete view: status");
         Assert
           (Ada.Directories.Exists (Zip),
            "Recent compression publishes beside the first selected source and preserves the complete view"
            & ": archive created");
         Assert
           (Files.Model.In_Recent_View (Model),
            "Recent compression publishes beside the first selected source and preserves the complete view"
            & ": still in Recent");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Item_Count (Model),
            2,
            "Recent compression publishes beside the first selected source and preserves the complete view"
            & ": item count");
         Mutation := Files.File_System.Copy_Tree (Zip, Copy_Zip);
         Assert (Mutation.Success, "prepare an archive in another source directory");
         Ada.Directories.Create_Path (Join (Two, "note"));
         Files.Settings.Note_Recent (Settings, Zip);
         Files.Settings.Note_Recent (Settings, Copy_Zip);
         Archives.Clear;
         Loaded := Files.File_System.Load_Item (Zip, Settings);
         Archives.Append (Loaded.Item);
         Loaded := Files.File_System.Load_Item (Copy_Zip, Settings);
         Archives.Append (Loaded.Item);
         Files.Model.Navigate_Recent (Model, Archives);
         Files.Model.Select_All_Visible (Model);
         Step := Complete_Operation (Model, Settings, Files.Operations.Extract_Selected (Model, Settings));
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operations.Operation_Success,
            "each Recent archive extracts beside itself with collision handling and leaves CWD intact: status");
         Assert
           (Files.Model.In_Recent_View (Model),
            "each Recent archive extracts beside itself with collision handling and leaves CWD intact"
            & ": still in Recent");
         Assert
           (File_Has_Bytes (Join (Join (Two, "note (1)"), "note.txt"), "note bytes"),
            "each Recent archive extracts beside itself with collision handling and leaves CWD intact"
            & ": note extracted under a collision name");
         Assert
           (File_Has_Bytes (Join (Join (One, "copy"), "report.txt"), "report bytes"),
            "each Recent archive extracts beside itself with collision handling and leaves CWD intact"
            & ": copy extracted beside its archive");
         Assert
           (not Ada.Directories.Exists (Join (Cwd, "note.zip")),
            "each Recent archive extracts beside itself with collision handling and leaves CWD intact"
            & ": no note.zip in CWD");
         Assert
           (not Ada.Directories.Exists (Join (Cwd, "note")),
            "each Recent archive extracts beside itself with collision handling and leaves CWD intact"
            & ": no note folder in CWD");
         Assert
           (not Ada.Directories.Exists (Join (Cwd, "copy")),
            "each Recent archive extracts beside itself with collision handling and leaves CWD intact"
            & ": no copy folder in CWD");
         Assert
           (File_Has_Bytes (Join (Cwd, "keep"), "working directory bytes"),
            "each Recent archive extracts beside itself with collision handling and leaves CWD intact"
            & ": CWD file intact");
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operations.Operation_Success,
            "Undo removes only the newly extracted adjacent folders: status");
         Assert
           (not Ada.Directories.Exists (Join (Two, "note (1)")),
            "Undo removes only the newly extracted adjacent folders: new note folder removed");
         Assert
           (not Ada.Directories.Exists (Join (One, "copy")),
            "Undo removes only the newly extracted adjacent folders: new copy folder removed");
         Assert
           (Ada.Directories.Exists (Join (Two, "note")),
            "Undo removes only the newly extracted adjacent folders: existing note folder kept");
         Assert (Ada.Directories.Exists (Zip), "Undo removes only the newly extracted adjacent folders: archive kept");
         Ada.Directories.Set_Directory (Saved_Directory (Cwd_Guard));
      end loop;
   exception
      when others =>
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         raise;
   end Test_Recent_Archive_Destinations;
