with Files.File_System.Trash;
with Files.File_System.Testing;

separate (Files_Suite.Trash)
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
           (Files.File_System.Testing.Trash_Backend_Of_Current_Environment
              = Files.File_System.Trash_Windows_Recycle_Bin,
            "trash backend can represent native Windows recycle-bin intent");
         declare
            Request : constant Files.File_System.Native_Trash_Request :=
              Files.File_System.Testing.Native_Trash_Request_For (Join (Root, "missing-for-native-trash.txt"));
            Native_Result : constant Files.File_System.Native_Trash_Result :=
              Files.File_System.Testing.Evaluate_Native_Trash (Request);
            Refused_Victim : constant String := Join (Root, "refused-by-native-trash.txt");
            Refused : Files.File_System.Mutation_Result;
         begin
            Assert (Request.Requires_Native_Api, "native trash request records native API requirement");
            Assert (not Request.Can_Use_Current_Process, "native trash request does not claim local fallback");
            --  "here" was always Linux, where the Windows adapter is of course not
            --  the target. On Windows it IS, and the binding is genuinely available.
            if Hostkit.Host.Current = Hostkit.Host.Windows
            then
               Assert (Native_Result.Supported,
                       "on Windows the native recycle-bin adapter is supported");
            else
               Assert (not Native_Result.Supported,
                       "off Windows the recycle-bin adapter is unsupported");
            end if;

            --  Evaluation never mutates, on any host.
            Assert (not Native_Result.Attempted, "native trash evaluation does not attempt mutation");
            Assert (not Native_Result.Completed, "native trash evaluation does not complete mutation");
            --  An evaluation carries a diagnostic only when it has something to
            --  report. On Windows the adapter is right here and working, so there is
            --  nothing to say; everywhere else the "unavailable" key IS the finding.
            if Hostkit.Host.Current = Hostkit.Host.Windows
            then
               Files_Suite.Support.Assert_Equal
                 (To_String (Native_Result.Error_Key),
                  "",
                  "on Windows a supported adapter evaluates without a diagnostic; key was "
                  & To_String (Native_Result.Error_Key));

            else
               Files_Suite.Support.Assert_Equal
                 (To_String (Native_Result.Error_Key),
                  "error.trash.native_unavailable",
                  "off Windows the evaluation reports native-unavailable");
            end if;

            --  The application's own trash path, with the desktop trash refusing
            --  every item: on Windows the Recycle Bin is reached and refuses, which
            --  is a failure, not an absent adapter -- the two must not read the
            --  same, or a broken Recycle Bin would look exactly like a missing one.
            --  Elsewhere the adapter is absent and says so. Either way the item
            --  stays where it was.
            Write_File (Refused_Victim, "keep me");
            Files.File_System.Testing.Refuse_Native_Trash (True);
            begin
               Refused := Files.File_System.Trash.Move_To_Trash (Refused_Victim);
            exception
               when others =>
                  Files.File_System.Testing.Refuse_Native_Trash (False);
                  raise;
            end;
            Files.File_System.Testing.Refuse_Native_Trash (False);
            Assert (not Refused.Success, "a refusing native trash does not report success");
            Files_Suite.Support.Assert_Equal
              (To_String (Refused.Error_Key),
               (if Hostkit.Host.Current = Hostkit.Host.Windows
                then "error.trash.failed"
                else "error.trash.native_unavailable"),
               "a refused move is a failure on Windows, an absent adapter elsewhere; key was "
               & To_String (Refused.Error_Key));
            Assert (Path_Exists (Refused_Victim), "the refused item is untouched");
            Ada.Directories.Delete_File (Refused_Victim);
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
            Mutation := Files.File_System.Trash.Move_To_Trash (Victim);

            if Hostkit.Host.Current = Hostkit.Host.Windows
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
         --  The Recycle Bin is not on a network share: asked to recycle there,
         --  the shell deletes the item for good. The same file, reached
         --  through this machine's administrative share, is refused before
         --  anything is touched.
         if Hostkit.Host.Current = Hostkit.Host.Windows
           and then Root'Length > 2 and then Root (Root'First + 1) = ':'
         then
            declare
               Victim : constant String := Join (Root, "on-a-share.txt");
               Shared : constant String :=
                 "\\localhost\" & Root (Root'First) & "$" & Join (Root (Root'First + 2 .. Root'Last), "on-a-share.txt");
            begin
               Write_File (Victim, "keep me");
               Assert (Path_Exists (Shared), "the file is reachable through \\localhost\" & Root (Root'First) & "$");
               Mutation := Files.File_System.Trash.Move_To_Trash_Preflight (Shared);
               Assert (not Mutation.Success, "recycling from a network share is refused");
               Files_Suite.Support.Assert_Equal
                 (To_String (Mutation.Error_Key), "error.trash.volume_unavailable",
                  "a share is refused as a volume the Recycle Bin does not hold");
               Assert (Path_Exists (Victim), "the refused file is untouched");
               Ada.Directories.Delete_File (Victim);
            end;
         end if;
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "macos");
         Assert
           (Files.File_System.Testing.Trash_Backend_Of_Current_Environment = Files.File_System.Trash_Macos_Native,
            "trash backend can represent native macOS trash intent");
      end Check;
   begin
      With_Trash_Environment (Check'Access);
   end Test_Native_Trash_Adapters;
