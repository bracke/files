with Files.File_System.Testing;

separate (Files_Suite.Operations)
   procedure Test_Native_Trash_Adapters (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Trash_Home   : constant String := Root & "_xdg_data";

      procedure Check is
         Mutation     : Files.File_System.Mutation_Result;
      begin
         Ada.Environment_Variables.Clear ("HOME");
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
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
              Files.File_System.Testing.Native_Trash_Request_For (Join (Root, "missing-for-native-trash.txt"));
            Native_Result : constant Files.File_System.Native_Trash_Result :=
              Files.File_System.Evaluate_Native_Trash (Request);
            Native_Execution : constant Files.File_System.Native_Trash_Result :=
              Files.File_System.Testing.Execute_Native_Trash (Request);
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
            Files_Suite.Support.Assert_Equal
              (To_String (Native_Result.Binding_Unit),
               "Hostkit.Trash",
               "Windows native trash result records the unit that owns the binding");
            Assert (not Native_Result.Desktop_Standard, "Windows native trash is not a desktop-standard fallback");
            Assert (Native_Result.Uses_Recycle_Bin, "Windows native trash result records recycle-bin target");
            Files_Suite.Support.Assert_Equal
              (To_String (Native_Result.Adapter_Name),
               "windows.recycle_bin",
               "Windows native trash result records adapter name");
            Files_Suite.Support.Assert_Equal
              (To_String (Native_Result.Native_Api_Name),
               "SHFileOperationW",
               "Windows native trash result records the API it actually calls");
            Files_Suite.Support.Assert_Equal
              (To_String (Native_Result.Operation_Name),
               "move_to_trash",
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
               Files_Suite.Support.Assert_Equal
                 (To_String (Native_Result.Error_Key),
                  "",
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
               Files_Suite.Support.Assert_Equal
                 (To_String (Native_Execution.Error_Key),
                  "error.trash.failed",
                  "a refused move is reported as a failure, not as an absent adapter; key was "
                  & To_String (Native_Execution.Error_Key));
            else
               Files_Suite.Support.Assert_Equal
                 (To_String (Native_Result.Error_Key),
                  "error.trash.native_unavailable",
                  "off Windows the evaluation reports native-unavailable");
               Assert (not Native_Execution.Supported, "native trash execution reports unsupported adapter");
               Assert (not Native_Execution.Attempted, "native trash execution does not attempt unsupported adapter");
               Assert
                 (not Native_Execution.Native_Binding_Available,
                  "native trash execution reports unavailable binding");
               Assert
                 (Native_Execution.Native_Binding_Status = Files.File_System.Native_API_Not_Target,
                  "native trash execution preserves binding status");
               Files_Suite.Support.Assert_Equal
                 (To_String (Native_Execution.Error_Key),
                  "error.trash.native_unavailable",
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
               Files_Suite.Support.Assert_Equal
                 (To_String (Mutation.Error_Key),
                  "error.trash.native_unavailable",
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
      end Check;
   begin
      With_Trash_Environment (Check'Access);
   end Test_Native_Trash_Adapters;
