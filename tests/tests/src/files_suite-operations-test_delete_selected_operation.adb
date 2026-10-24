separate (Files_Suite.Operations)
   procedure Test_Delete_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Trash_Home   : constant String := Root & "_xdg_data";
      Mac_Home     : constant String := Root & "_mac_home";
      Trash_File   : constant String := Join (Join (Trash_Home, "Trash"), "files");
      Trash_Info   : constant String := Join (Join (Trash_Home, "Trash"), "info");
      Special_Path  : constant String := Join (Root, "space % file.txt");
      Nested_Trash_Source : constant String := Join (Root, "nested-trash-source");
      Had_Xdg_Data : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Home     : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Had_Backend  : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg_Data : Unbounded_String;
      Old_Home     : Unbounded_String;
      Old_Backend  : Unbounded_String;
      Load         : Files.File_System.Directory_Load_Result;
      Model        : Files.Model.Window_Model;
      Result       : Files.Controller.Controller_Result;
      Mutation      : Files.File_System.Mutation_Result;

      procedure Restore_Environment is
      begin
         if Had_Xdg_Data then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", To_String (Old_Xdg_Data));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;

         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;

         if Had_Backend then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", To_String (Old_Backend));
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      if Had_Xdg_Data then
         Old_Xdg_Data := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Home then
         Old_Home := To_Unbounded_String (Ada.Environment_Variables.Value ("HOME"));
      end if;
      if Had_Backend then
         Old_Backend := To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND"));
      end if;

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Assert
        (Files.File_System.Trash_Deletion_Date (Ada.Calendar.Time_Of (2024, 2, 3, 0.0)) =
         "2024-02-03T00:00:00",
         "trash deletion date formats midnight");
      Assert
        (Files.File_System.Trash_Deletion_Date (Ada.Calendar.Time_Of (2024, 2, 3, 60.9)) =
         "2024-02-03T00:01:00",
         "trash deletion date floors fractional seconds");
      Assert
        (Files.File_System.Trash_Deletion_Date (Ada.Calendar.Time_Of (2024, 2, 3, 86_399.9)) =
         "2024-02-03T23:59:59",
         "trash deletion date does not round up near midnight");
      --  On Windows the desktop trash is the Recycle Bin, which is always there:
      --  "no trash base exists" is not a state that platform can be in. Select
      --  the freedesktop backend explicitly, and the absence of a base is then
      --  meaningful on every host.
      Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
      Ada.Environment_Variables.Clear ("HOME");
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Assert (not Files.File_System.Trash_Is_Available, "trash availability detects missing trash base");
      Assert
        (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Unavailable,
         "trash backend reports unavailable when no trash base exists");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", "relative-trash-data");
      Assert
        (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Unavailable
         and then not Files.File_System.Trash_Is_Available,
         "a relative XDG data home cannot redirect trash into the process directory");
      Ada.Environment_Variables.Clear ("XDG_DATA_HOME");

      --  And with nothing selected, each platform falls back to its own desktop
      --  trash: the Recycle Bin on Windows, the freedesktop layout elsewhere.
      Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
      if Files.Platform.Current_API_Profile.Adapter = Files.File_System.Native_Adapter_Windows then
         Assert
           (Files.File_System.Trash_Backend_Of_Current_Environment
              = Files.File_System.Trash_Windows_Recycle_Bin,
            "Windows falls back to the Recycle Bin, which needs no trash base");
         Assert (Files.File_System.Trash_Is_Available,
                 "the Recycle Bin is always available");
      else
         Assert
           (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Unavailable,
            "elsewhere, no trash base means no trash");
      end if;
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Assert
        (not Files.File_System.Trash_Capabilities_Of_Current_Environment.Metadata_Sidecar,
         "unavailable trash backend reports no metadata sidecar support");
      Assert
        (Files.File_System.Trash_Capabilities_Of_Current_Environment.Native_Diagnostics,
         "trash capabilities expose native diagnostic policy");
      Assert
        (Files.File_System.Trash_Capabilities_Of_Current_Environment.Multi_Item_Preflight,
         "trash capabilities expose multi-item preflight policy");
      Write_File (Join (Root, "blocked-trash-parent"));
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Join (Root, "blocked-trash-parent"), "xdg"));
      Assert
        (not Files.File_System.Trash_Is_Available,
         "trash availability rejects a regular file in the trash parent chain");
      Mutation := Files.File_System.Move_To_Trash_Preflight (Join (Root, "missing-for-blocked-trash.txt"));
      Assert
        (To_String (Mutation.Error_Key) = "error.trash.failed",
         "missing trash target still reports failed trash mutation");
      Mutation :=
        Files.File_System.Move_To_Trash_Preflight
          (Root & "/bad" & Character'Val (0) & "trash-target.txt");
      Assert (not Mutation.Success, "malformed trash target reports failed trash mutation");
      Assert
        (To_String (Mutation.Error_Key) = "error.trash.failed",
         "malformed trash target reports failed trash diagnostic");
      Write_File (Join (Root, "blocked-trash-target.txt"));
      Mutation := Files.File_System.Move_To_Trash_Preflight (Join (Root, "blocked-trash-target.txt"));
      Assert (not Mutation.Success, "trash preflight rejects blocked trash parent chain");
      Assert
        (To_String (Mutation.Error_Key) = "error.trash.unavailable",
         "blocked trash parent chain reports unavailable trash");
      Ada.Directories.Delete_File (Join (Root, "blocked-trash-parent"));
      Ada.Directories.Delete_File (Join (Root, "blocked-trash-target.txt"));
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Assert (Files.File_System.Trash_Is_Available, "trash availability detects XDG trash base");
      Assert
        (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Xdg_Data_Home,
         "trash backend reports XDG data home when configured");
      Assert
        (Files.File_System.Trash_Capabilities_Of_Current_Environment.Metadata_Sidecar,
         "XDG trash backend reports trashinfo sidecar support");
      Assert
        (Files.File_System.Trash_Capabilities_Of_Current_Environment.Collision_Safe_Name,
         "XDG trash backend reports collision-safe naming");
      Assert
        (Files.File_System.Trash_Capabilities_Of_Current_Environment.Multi_Item_Preflight,
         "XDG trash backend reports multi-item preflight support");
      --  "/" is not a root on Windows; the drive is.
      Mutation := Files.File_System.Move_To_Trash_Preflight (Filesystem_Root);
      Assert (not Mutation.Success, "trash preflight rejects filesystem root");
      Assert
        (To_String (Mutation.Error_Key) = "error.trash.failed",
         "filesystem root trash preflight reports failed trash mutation");
      declare
         Prefix_Source : constant String := Join (Root, "trash-prefix-source");
         Prefix_Base   : constant String := Prefix_Source & "-xdg";
      begin
         Write_File (Prefix_Source);
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Prefix_Base);
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         Mutation := Files.File_System.Move_To_Trash_Preflight (Prefix_Source);
         Assert (Mutation.Success, "trash preflight accepts sibling paths sharing a prefix");
         Assert
           (To_String (Mutation.Error_Key) = "",
            "trash prefix-sibling preflight has no diagnostic");
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         Ada.Directories.Delete_File (Prefix_Source);
      end;
      if Hostkit.Host.Current /= Hostkit.Host.Windows then
         declare
            Backslash_Data : constant String := Join (Root, "backslash-xdg");
            Backslash_Base : constant String := Join (Backslash_Data, "Trash");
            Backslash_Source : constant String := Join (Backslash_Data, "Trash\victim");
         begin
            Ada.Directories.Create_Path (Join (Backslash_Base, "files"));
            Ada.Directories.Create_Path (Join (Backslash_Base, "info"));
            Write_File (Backslash_Source, "sibling");
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Backslash_Data);
            Mutation := Files.File_System.Move_To_Trash_Preflight (Backslash_Source);
            Assert
              (Mutation.Success,
               "a POSIX backslash sibling is not mistaken for a child of the trash directory");
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
            Ada.Directories.Delete_File (Backslash_Source);
            Ada.Directories.Delete_Directory (Join (Backslash_Base, "files"));
            Ada.Directories.Delete_Directory (Join (Backslash_Base, "info"));
            Ada.Directories.Delete_Directory (Backslash_Base);
            Ada.Directories.Delete_Directory (Backslash_Data);
         end;
      end if;
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Assert
        (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Windows_Recycle_Bin,
         "trash backend can represent native Windows recycle-bin intent");
      Assert
        (Files.File_System.Trash_Capabilities_Of_Current_Environment.Native_Platform,
         "native Windows trash backend reports native-platform intent");
      Assert
        (not Files.File_System.Trash_Capabilities_Of_Current_Environment.Permanent_Delete,
         "native trash capability does not opt into permanent deletion");
      declare
         Request : constant Files.File_System.Native_Trash_Request :=
           Files.File_System.Native_Trash_Request_For (Join (Root, "missing-for-native-trash.txt"));
         Native_Result : constant Files.File_System.Native_Trash_Result :=
           Files.File_System.Evaluate_Native_Trash (Request);
         Native_Execution : constant Files.File_System.Native_Trash_Result :=
           Files.File_System.Execute_Native_Trash (Request);
      begin
         Assert (Request.Requires_Native_Api, "native trash request records native API requirement");
         Assert (not Request.Can_Use_Current_Process, "native trash request does not claim local fallback");
         --  "here" was always Linux, where the Windows adapter is of course not
         --  the target. On Windows it IS, and the binding is genuinely available.
         if Files.Platform.Current_API_Profile.Adapter
              = Files.File_System.Native_Adapter_Windows
         then
            Assert (Native_Result.Supported,
                    "on Windows the native recycle-bin adapter is supported");
            Assert (Native_Result.Native_Binding_Available,
                    "on Windows the native trash binding is available");
            Assert
              (Native_Result.Native_Binding_Status
                 = Files.File_System.Native_API_Binding_Available,
               "on Windows the native trash binding reports available");
         else
            Assert (not Native_Result.Supported,
                    "off Windows the recycle-bin adapter is unsupported");
            Assert (not Native_Result.Native_Binding_Available,
                    "off Windows the Windows trash binding is unavailable");
            Assert
              (Native_Result.Native_Binding_Status
                 = Files.File_System.Native_API_Not_Target,
               "off Windows the Windows trash binding is not the target");
         end if;

         --  Evaluation never mutates, on any host.
         Assert (not Native_Result.Attempted, "native trash evaluation does not attempt mutation");
         Assert (not Native_Result.Completed, "native trash evaluation does not complete mutation");
         Assert
           (To_String (Native_Result.Binding_Unit) = "Hostkit.Trash",
            "Windows native trash result records the unit that owns the binding");
         Assert (not Native_Result.Desktop_Standard, "Windows native trash is not a desktop-standard fallback");
         Assert (Native_Result.Uses_Recycle_Bin, "Windows native trash result records recycle-bin target");
         Assert
           (To_String (Native_Result.Adapter_Name) = "windows.recycle_bin",
            "Windows native trash result records adapter name");
         Assert
           (To_String (Native_Result.Native_Api_Name) = "SHFileOperationW",
            "Windows native trash result records the API it actually calls");
         Assert
           (To_String (Native_Result.Operation_Name) = "move_to_trash",
            "native trash result records operation name");
         Assert (Native_Result.Preserves_Metadata, "native trash result records metadata-preservation intent");
         Assert
           (not Native_Result.Requires_User_Consent,
            "native trash result records no in-app consent requirement");
         --  An evaluation carries a diagnostic only when it has something to
         --  report. On Windows the adapter is right here and working, so there is
         --  nothing to say; everywhere else the "unavailable" key IS the finding.
         if Files.Platform.Current_API_Profile.Adapter
              = Files.File_System.Native_Adapter_Windows
         then
            Assert
              (To_String (Native_Result.Error_Key) = "",
               "on Windows a supported adapter evaluates without a diagnostic; key was "
               & To_String (Native_Result.Error_Key));

            --  Executing against a path that does not exist: the adapter is real,
            --  so it genuinely calls the shell and the shell genuinely refuses.
            --  That is a failed attempt, not an unsupported one -- and the two
            --  must not be reported the same way, or a broken Recycle Bin would
            --  look exactly like a missing one.
            Assert (Native_Execution.Supported, "on Windows the adapter is supported");
            Assert (Native_Execution.Attempted, "on Windows the shell is actually called");
            Assert
              (not Native_Execution.Completed,
               "and it refuses a path that does not exist");
            Assert
              (Native_Execution.Native_Binding_Available,
               "on Windows the binding stays available across execution");
            Assert
              (Native_Execution.Native_Binding_Status
                 = Files.File_System.Native_API_Binding_Available,
               "on Windows execution preserves binding status");
            Assert
              (To_String (Native_Execution.Error_Key) = "error.trash.failed",
               "a refused move is reported as a failure, not as an absent adapter; key was "
               & To_String (Native_Execution.Error_Key));
         else
            Assert
              (To_String (Native_Result.Error_Key) = "error.trash.native_unavailable",
               "off Windows the evaluation reports native-unavailable");
            Assert (not Native_Execution.Supported, "native trash execution reports unsupported adapter");
            Assert (not Native_Execution.Attempted, "native trash execution does not attempt unsupported adapter");
            Assert
              (not Native_Execution.Native_Binding_Available,
               "native trash execution reports unavailable binding");
            Assert
              (Native_Execution.Native_Binding_Status = Files.File_System.Native_API_Not_Target,
               "native trash execution preserves binding status");
            Assert
              (To_String (Native_Execution.Error_Key) = "error.trash.native_unavailable",
               "off Windows, native trash execution reports native-unavailable");
         end if;
      end;
      --  This used a path that did not exist, because the preflight refused a
      --  native backend outright and never got as far as looking. It does look
      --  now, so give it something real -- and then the answer depends on where we
      --  are: on Windows the Recycle Bin takes it, and everywhere else the Windows
      --  adapter is a stub that says so.
      declare
         Victim : constant String := Join (Root, "for-native-trash.txt");
      begin
         Write_File (Victim, "bin me");
         Mutation := Files.File_System.Move_To_Trash (Victim);

         if Files.Platform.Current_API_Profile.Adapter
              = Files.File_System.Native_Adapter_Windows
         then
            Assert (Mutation.Success,
                    "on Windows the Recycle Bin takes the item; error was "
                    & To_String (Mutation.Error_Key));
            Assert (not Path_Exists (Victim),
                    "the item is gone from its directory once the shell has it");
         else
            Assert (not Mutation.Success,
                    "off Windows the recycle-bin adapter cannot do it");
            Assert
              (To_String (Mutation.Error_Key) = "error.trash.native_unavailable",
               "and it fails as recoverable data, not an exception; key was "
               & To_String (Mutation.Error_Key));
         end if;

         --  Off Windows the move fails and the file stays, which would leave the
         --  scratch root holding one item more than the tests after this expect.
         if Path_Exists (Victim) then
            Ada.Directories.Delete_File (Victim);
         end if;
      end;
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "macos");
      Assert
        (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Macos_Native,
         "trash backend can represent native macOS trash intent");
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
           Files.File_System.Native_Trash_Request_For (Join (Root, "native-execute.txt"));
         Native_Execution : constant Files.File_System.Native_Trash_Result :=
           Files.File_System.Execute_Native_Trash (Request);
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
         Assert
           (To_String (Native_Execution.Binding_Unit) = "Files.File_System.Move_To_Trash",
            "XDG trash execution records binding unit");
         Assert
           (not Ada.Directories.Exists (Join (Root, "native-execute.txt")),
            "XDG trash execution moves source entry");
         Assert
           (To_String (Native_Execution.Adapter_Name) = "xdg.trash",
            "XDG trash execution records adapter name");
         Assert
           (To_String (Native_Execution.Error_Key) = "",
            "XDG trash execution has no error key");
      end;
      Write_File (Join (Root, "doomed.txt"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "doomed.txt");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
      Assert (Result.Command = Files.Commands.Delete_Selected_Items_Command, "Delete routes through command registry");
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "available trash moves selected item");
      Assert (To_String (Result.Operation.Path) = Join (Root, "doomed.txt"), "delete operation reports target path");
      Assert (To_String (Result.Operation.Error_Key) = "", "successful trash move has no error key");
      Assert (Files.Model.Last_Error_Key (Model) = "", "successful trash move clears model error");
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
      Assert (Files.Model.Selected_Count (Model) = 0, "successful delete reconciles selection");
      Mutation := Files.File_System.Move_To_Trash (Join (Trash_File, "doomed.txt"));
      Assert (not Mutation.Success, "trash preflight rejects items already inside trash");
      Assert
        (To_String (Mutation.Error_Key) = "error.trash.failed",
         "already-trashed item reports trash failure");
      Assert
        (Ada.Directories.Exists (Join (Trash_File, "doomed.txt")),
         "already-trashed item remains in place after rejected trash move");

      Write_File (Join (Root, "doomed.txt"), "again");
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "refresh loads collision target");
      Select_Name (Model, "doomed.txt");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "second same-name delete succeeds");
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

      Write_File (Join (Root, "doomed2.txt"));
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "refresh loads second delete target");
      Select_Name (Model, "doomed2.txt");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace);
      Assert
        (Result.Command = Files.Commands.Delete_Selected_Items_Command,
         "Backspace routes through same delete command");
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "Backspace delete uses trash operation");
      Assert (Ada.Directories.Exists (Join (Trash_File, "doomed2.txt")), "Backspace moves file to trash");

      Write_File (Special_Path);
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "refresh loads encoded trash target");
      Select_Name (Model, "space % file.txt");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "encoded trash target moves to trash");
      --  What this is about is the encoding of the awkward characters, and that is
      --  host-independent. The absolute path in front of them is not: it was spelled
      --  out here as Full_Name (Root) & "/...", which is only ever true on POSIX. A
      --  Windows path is "C:\..." and the encoder escapes its ':' and '\' too, so the
      --  literal never matched. Assert the part this test is named for, and leave the
      --  round-trip -- that the recorded path decodes back to the original location --
      --  to Test_Restore_From_Trash, which is what that test exists to prove.
      Assert
        (Project_Tools.Files.File_Contains
           (Join (Trash_Info, "space % file.txt.trashinfo"), "Path="),
         "trashinfo records the original path");
      Assert
        (Project_Tools.Files.File_Contains
           (Join (Trash_Info, "space % file.txt.trashinfo"), "space%20%25%20file.txt"),
         "trashinfo path percent-encodes spaces and percent signs");

      Write_File (Join (Root, "multi-a.txt"));
      Write_File (Join (Root, "multi-b.txt"));
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "refresh loads multi-delete targets");
      Files.Model.Set_Filter (Model, "multi-");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "multi-selection delete succeeds");
      Assert (Ada.Directories.Exists (Join (Trash_File, "multi-a.txt")), "multi-delete moves first file");
      Assert (Ada.Directories.Exists (Join (Trash_File, "multi-b.txt")), "multi-delete moves second file");
      Assert (not Ada.Directories.Exists (Join (Root, "multi-a.txt")), "multi-delete removes first source file");
      Assert (not Ada.Directories.Exists (Join (Root, "multi-b.txt")), "multi-delete removes second source file");

      Write_File (Join (Root, "partial-a.txt"));
      Write_File (Join (Root, "partial-b.txt"));
      Result := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Result.Operation.Status = Files.Operations.Operation_Success, "refresh loads partial-delete targets");
      Files.Model.Set_Filter (Model, "partial-");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Ada.Directories.Delete_File (Join (Root, "partial-b.txt"));
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
      Assert (Result.Operation.Status = Files.Operations.Operation_Failed, "partial multi-delete reports failure");
      Assert
        (To_String (Result.Operation.Error_Key) = "error.trash.failed",
         "partial multi-delete reports trash failure");
      Assert
        (not Ada.Directories.Exists (Join (Trash_File, "partial-a.txt")),
         "partial multi-delete does not move earlier files before preflight failure");
      Assert
        (Ada.Directories.Exists (Join (Root, "partial-a.txt")),
         "partial multi-delete leaves earlier source files in place");
      Assert (Files.Model.Item_Count (Model) = 1, "partial multi-delete reloads stale directory model");
      Assert (Files.Model.Last_Error_Key (Model) = "error.trash.failed", "partial multi-delete keeps error state");

      Ada.Directories.Create_Path (Nested_Trash_Source);
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Nested_Trash_Source, "xdg-data"));
      Mutation := Files.File_System.Move_To_Trash (Nested_Trash_Source);
      Assert (not Mutation.Success, "trash move into a source subdirectory fails");
      Assert
        (To_String (Mutation.Error_Key) = "error.trash.failed",
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
         Assert
           (Guard_Result.Operation.Status = Files.Operations.Operation_Failed,
            "multi-delete preflights nested trash targets");
         Assert
           (To_String (Guard_Result.Operation.Error_Key) = "error.trash.failed",
            "multi-delete nested trash preflight reports trash failure");
         Assert
           (Ada.Directories.Exists (First_File),
            "multi-delete nested trash preflight does not move earlier selected files");
         Assert (Ada.Directories.Exists (Guard_Directory), "nested trash preflight keeps guarded directory");
         Assert
           (not Ada.Directories.Exists (Join (Join (Guard_Trash, "files"), "guard-preflight-a.txt")),
            "multi-delete nested trash preflight does not create a trash target for earlier files");
         Assert
           (Files.Model.Last_Error_Key (Guard_Model) = "error.trash.failed",
            "multi-delete nested trash preflight preserves model error");
      end;

      Project_Tools.Files.Delete_Tree (Mac_Home);
      Ada.Directories.Create_Path (Join (Mac_Home, ".Trash"));
      Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
      Ada.Environment_Variables.Set ("HOME", Mac_Home);
      Write_File (Join (Root, "mac-trash.txt"));
      Mutation := Files.File_System.Move_To_Trash (Join (Root, "mac-trash.txt"));
      Assert (Mutation.Success, "macOS-style home trash fallback moves files");
      Assert
        (Files.File_System.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Macos_Home,
         "trash backend reports macOS-style home trash when present");
      Assert
        (Ada.Directories.Exists (Join (Join (Mac_Home, ".Trash"), "mac-trash.txt")),
         "macOS-style home trash stores the file directly under ~/.Trash");
      Assert
        (not Ada.Directories.Exists (Join (Join (Mac_Home, ".Trash"), "files")),
         "macOS-style home trash does not create a freedesktop files/ subdirectory");
      Assert
        (not Ada.Directories.Exists (Join (Join (Mac_Home, ".Trash"), "info")),
         "macOS-style home trash does not create a freedesktop info/ subdirectory");

      Project_Tools.Files.Delete_Tree (Trash_Home);
      Project_Tools.Files.Delete_Tree (Mac_Home);
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Delete_Selected_Operation;
