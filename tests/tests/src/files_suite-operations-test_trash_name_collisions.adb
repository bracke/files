separate (Files_Suite.Operations)
   procedure Test_Trash_Name_Collisions (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Trash_Home   : constant String := Root & "_xdg_data";
      Trash_File   : constant String := Join (Join (Trash_Home, "Trash"), "files");
      Trash_Info   : constant String := Join (Join (Trash_Home, "Trash"), "info");

      procedure Check is
         Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Load         : Files.File_System.Directory_Load_Result;
         Model        : Files.Model.Window_Model;
         Result       : Files.Controller.Controller_Result;
         Mutation     : Files.File_System.Mutation_Result;
      begin
         Ada.Environment_Variables.Clear ("HOME");
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         --  Trash a first doomed.txt so that the one below collides with it.
         Write_File (Join (Root, "doomed.txt"));
         declare
            Trashed : constant Files.File_System.Mutation_Result :=
              Files.File_System.Move_To_Trash (Join (Root, "doomed.txt"));
            pragma Unreferenced (Trashed);
         begin
            null;
         end;

         Write_File (Join (Root, "doomed.txt"), "again");
         Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Result.Operation.Status,
            Files.Operations.Operation_Success,
            "refresh loads collision target");
         Select_Name (Model, "doomed.txt");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
         Files_Suite.Support.Assert_Equal
           (Result.Operation.Status,
            Files.Operations.Operation_Success,
            "second same-name delete succeeds");
         Assert (Ada.Directories.Exists (Join (Trash_File, "doomed.txt.2")), "trash collision chooses suffix");
         Assert
           (Ada.Directories.Exists (Join (Trash_Info, "doomed.txt.2.trashinfo")),
            "trash collision writes suffixed metadata");

         Write_File (Join (Trash_Info, "sidecar-only.txt.trashinfo"));
         Write_File (Join (Root, "sidecar-only.txt"));
         Mutation := Files.File_System.Move_To_Trash (Join (Root, "sidecar-only.txt"));
         Assert (Mutation.Success, "trash sidecar-only collision succeeds with suffix");
         Assert
           (Ada.Directories.Exists (Join (Trash_File, "sidecar-only.txt.2")),
            "trash sidecar-only collision chooses suffix");
         Assert
           (Ada.Directories.Exists (Join (Trash_Info, "sidecar-only.txt.2.trashinfo")),
            "trash sidecar-only collision writes suffixed metadata");
         Assert
           (Ada.Directories.Exists (Join (Trash_Info, "sidecar-only.txt.trashinfo")),
            "trash sidecar-only collision preserves existing metadata sidecar");
      end Check;
   begin
      With_Trash_Environment (Check'Access);
   end Test_Trash_Name_Collisions;
