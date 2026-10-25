with Files.File_System.Testing;

separate (Files_Suite.Operations)
   procedure Test_Xdg_Trash_Move (T : in out AUnit.Test_Cases.Test_Case'Class) is
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
         --  Everything from here on is about the freedesktop implementation -- the
         --  trash directory, the .trashinfo metadata, the collision naming. Clearing
         --  the variable used to select it, back when XDG was the default everywhere.
         --  Windows now defaults to the Recycle Bin, which has none of those things,
         --  so ask for XDG by name and it stays exercised on every host instead of
         --  only where it happens to be the default.
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         Write_File (Join (Root, "native-execute.txt"));
         declare
            Request : constant Files.File_System.Native_Trash_Request :=
              Files.File_System.Testing.Native_Trash_Request_For (Join (Root, "native-execute.txt"));
            Native_Execution : constant Files.File_System.Native_Trash_Result :=
              Files.File_System.Testing.Execute_Native_Trash (Request);
         begin
            Assert (Request.Can_Use_Current_Process, "XDG trash request can execute in current process");
            Assert (Native_Execution.Supported, "XDG trash execution reports supported adapter");
            Assert (Native_Execution.Attempted, "XDG trash execution attempts mutation");
            Assert (Native_Execution.Completed, "XDG trash execution completes mutation");
            Assert (Native_Execution.Desktop_Standard, "XDG trash execution reports desktop-standard backend");
            Assert
              (not Native_Execution.Native_Binding_Available,
               "XDG trash execution does not claim OS-specific native binding");
            Assert
              (Native_Execution.Native_Binding_Status = Files.File_System.Native_API_Binding_Missing,
               "XDG trash execution reports no OS-specific native binding");
            Files_Suite.Support.Assert_Equal
              (To_String (Native_Execution.Binding_Unit),
               "Files.File_System.Move_To_Trash",
               "XDG trash execution records binding unit");
            Assert
              (not Ada.Directories.Exists (Join (Root, "native-execute.txt")),
               "XDG trash execution moves source entry");
            Files_Suite.Support.Assert_Equal
              (To_String (Native_Execution.Adapter_Name),
               "xdg.trash",
               "XDG trash execution records adapter name");
            Files_Suite.Support.Assert_Equal
              (To_String (Native_Execution.Error_Key),
               "",
               "XDG trash execution has no error key");
         end;
         Write_File (Join (Root, "doomed.txt"));
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Select_Name (Model, "doomed.txt");
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
         Files_Suite.Support.Assert_Equal
           (Result.Command,
            Files.Commands.Delete_Selected_Items_Command,
            "Delete routes through command registry");
         Files_Suite.Support.Assert_Equal
           (Result.Operation.Status,
            Files.Operations.Operation_Success,
            "available trash moves selected item");
         Files_Suite.Support.Assert_Equal
           (To_String (Result.Operation.Path),
            Join (Root, "doomed.txt"),
            "delete operation reports target path");
         Files_Suite.Support.Assert_Equal
           (To_String (Result.Operation.Error_Key),
            "",
            "successful trash move has no error key");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model),
            "",
            "successful trash move clears model error");
         Assert (not Ada.Directories.Exists (Join (Root, "doomed.txt")), "trash move removes file from source");
         Assert (Ada.Directories.Exists (Join (Trash_File, "doomed.txt")), "trash move stores file under XDG trash");
         Assert
           (Ada.Directories.Exists (Join (Trash_Info, "doomed.txt.trashinfo")),
            "trash move writes trashinfo metadata");
         if Hostkit.Metadata.Mode_Bits_Are_Native then
            declare
               Available : Boolean := False;
            begin
               Assert
                 (Files.File_System.Permission_Bits_Of (Join (Trash_Home, "Trash"), Available)
                    mod 8#1000# = 8#700# and then Available,
                  "trash root is owner-only");
               Assert
                 (Files.File_System.Permission_Bits_Of (Trash_File, Available)
                    mod 8#1000# = 8#700# and then Available,
                  "trash payload directory is owner-only");
               Assert
                 (Files.File_System.Permission_Bits_Of (Trash_Info, Available)
                    mod 8#1000# = 8#700# and then Available,
                  "trash metadata directory is owner-only");
               Assert
                 (Files.File_System.Permission_Bits_Of
                    (Join (Trash_Info, "doomed.txt.trashinfo"), Available)
                    mod 8#1000# = 8#600# and then Available,
                  "trash metadata sidecar is owner-only");
            end;
         end if;
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Count (Model),
            0,
            "successful delete reconciles selection");
         Mutation := Files.File_System.Move_To_Trash (Join (Trash_File, "doomed.txt"));
         Assert (not Mutation.Success, "trash preflight rejects items already inside trash");
         Files_Suite.Support.Assert_Equal
           (To_String (Mutation.Error_Key),
            "error.trash.failed",
            "already-trashed item reports trash failure");
         Assert
           (Ada.Directories.Exists (Join (Trash_File, "doomed.txt")),
            "already-trashed item remains in place after rejected trash move");
      end Check;
   begin
      With_Trash_Environment (Check'Access);
   end Test_Xdg_Trash_Move;
