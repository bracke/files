separate (Files_Suite.Operations)
   procedure Test_Nested_Trash_Preflight (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Nested_Trash_Source : constant String := Join (Root, "nested-trash-source");

      procedure Check is
         Mutation     : Files.File_System.Mutation_Result;
      begin
         Ada.Environment_Variables.Clear ("HOME");
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         Ada.Directories.Create_Path (Nested_Trash_Source);
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Nested_Trash_Source, "xdg-data"));
         Mutation := Files.File_System.Move_To_Trash (Nested_Trash_Source);
         Assert (not Mutation.Success, "trash move into a source subdirectory fails");
         Files_Suite.Support.Assert_Equal
           (To_String (Mutation.Error_Key),
            "error.trash.failed",
            "nested trash move reports trash failure");
         Assert (Ada.Directories.Exists (Nested_Trash_Source), "failed nested trash keeps source directory");
         Assert
           (not Ada.Directories.Exists
              (Join (Join (Join (Nested_Trash_Source, "xdg-data"), "Trash"), "info")
               & "/nested-trash-source.trashinfo"),
            "failed nested trash removes stale trashinfo metadata");

         declare
            Guard_Directory : constant String := Join (Root, "guard-preflight-z-dir");
            First_File      : constant String := Join (Root, "guard-preflight-a.txt");
            Guard_Trash     : constant String := Join (Join (Guard_Directory, "xdg-data"), "Trash");
            Guard_Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
            Guard_Load      : Files.File_System.Directory_Load_Result;
            Guard_Model     : Files.Model.Window_Model;
            Guard_Result    : Files.Controller.Controller_Result;
         begin
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Guard_Directory, "xdg-data"));
            Write_File (First_File);
            Ada.Directories.Create_Path (Guard_Directory);
            Guard_Load := Files.File_System.Load_Directory (Root, Guard_Settings);
            Assert (Guard_Load.Success, "guarded multi-delete setup loads");
            Files.Model.Initialize (Guard_Model, Root, Guard_Load.Items, Root);
            Files.Model.Set_Filter (Guard_Model, "guard-preflight-");
            Files.Model.Select_Visible (Guard_Model, 1);
            Files.Model.Toggle_Visible_Selection (Guard_Model, 2);

            Guard_Result := Files.Controller.Handle_Key (Guard_Model, Guard_Settings, Guikit.Input.Key_Delete);
            Files_Suite.Support.Assert_Equal
              (Guard_Result.Operation.Status,
               Files.Operations.Operation_Failed,
               "multi-delete preflights nested trash targets");
            Files_Suite.Support.Assert_Equal
              (To_String (Guard_Result.Operation.Error_Key),
               "error.trash.failed",
               "multi-delete nested trash preflight reports trash failure");
            Assert
              (Ada.Directories.Exists (First_File),
               "multi-delete nested trash preflight does not move earlier selected files");
            Assert (Ada.Directories.Exists (Guard_Directory), "nested trash preflight keeps guarded directory");
            Assert
              (not Ada.Directories.Exists (Join (Join (Guard_Trash, "files"), "guard-preflight-a.txt")),
               "multi-delete nested trash preflight does not create a trash target for earlier files");
            Files_Suite.Support.Assert_Equal
              (Files.Model.Last_Error_Key (Guard_Model),
               "error.trash.failed",
               "multi-delete nested trash preflight preserves model error");
         end;
      end Check;
   begin
      With_Trash_Environment (Check'Access);
   end Test_Nested_Trash_Preflight;
