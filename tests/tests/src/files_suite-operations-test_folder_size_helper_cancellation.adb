separate (Files_Suite.Operations)
   procedure Test_Folder_Size_Helper_Cancellation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Marker : constant String := Join (Root, "size-started");
      Had_Flag : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TEST_STALL_FOLDER_SIZES");
      Old_Flag : constant String := Ada.Environment_Variables.Value ("FILES_TEST_STALL_FOLDER_SIZES", "");
      Started, Previous, Path : Unbounded_String;
      Result : Files.File_System.Directory_Size_Result;
      Available, Finished, Cancelled : Boolean;
      Empty : Files.Process_Jobs.Session;
      Before : Ada.Calendar.Time;
      Targets : Files.Folder_Size.Path_Vectors.Vector;

      procedure Restore is
      begin
         Files.Folder_Size.Cancel;
         if Had_Flag then
            Ada.Environment_Variables.Set ("FILES_TEST_STALL_FOLDER_SIZES", Old_Flag);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_STALL_FOLDER_SIZES");
         end if;
      end Restore;

      procedure Await_Helper is
         File : Ada.Text_IO.File_Type;
      begin
         for Attempt in Files_Suite.Support.Polling loop
            exit when Ada.Directories.Exists (Marker);
         end loop;
         Assert (Ada.Directories.Exists (Marker), "the size helper reaches stalled filesystem work");
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Marker);
         Started := To_Unbounded_String (Join (Ada.Text_IO.Get_Line (File), "started"));
         Ada.Text_IO.Close (File);
         Assert (Ada.Directories.Exists (To_String (Started)), "the stalled helper owns its transport");
      end Await_Helper;

      procedure Await_Reaped (Started : Unbounded_String) is
      begin
         for Attempt in Files_Suite.Support.Polling loop
            Files.Process_Jobs.Poll (Empty, Finished, Cancelled);
            exit when not Ada.Directories.Exists (To_String (Started));
         end loop;
         Assert (not Ada.Directories.Exists (To_String (Started)),
                 "the abandoned size helper is terminated and reaped");
      end Await_Reaped;
   begin
      Reset_Root;
      Files.Folder_Size.Cancel;
      loop
         Files.Folder_Size.Take (Path, Result, Available);
         exit when not Available;
      end loop;
      Files.Folder_Size.Request ("relative-folder-size-target");
      Assert
        (not Files.Folder_Size.Is_Active
         and then Files.Folder_Size.Target_For_Test = "",
         "folder-size requests reject relative targets before launching a helper");
      Files.Folder_Size.Request
        (Root & Character'Val (0) & "ignored");
      Assert
        (not Files.Folder_Size.Is_Active
         and then Files.Folder_Size.Target_For_Test = "",
         "folder-size requests reject NUL-containing targets before launching a helper");
      Ada.Environment_Variables.Set ("FILES_TEST_STALL_FOLDER_SIZES", Marker);
      Before := Ada.Calendar.Clock;
      Files.Folder_Size.Request (Join (Root, "unreadable-or-missing"));
      --  Posting starts a helper process, which on a busy Windows runner can
      --  alone take longer than a quarter second; inspecting the stalled
      --  target in the caller would block far longer than this bound.
      Assert (Ada.Calendar.Clock - Before < 2.0, "posting a size request does not inspect its target");
      Await_Helper;
      Targets.Append (To_Unbounded_String (Join (Root, "unreadable-or-missing")));
      Targets.Append (To_Unbounded_String (Join (Root, "another-window")));
      Before := Ada.Calendar.Clock;
      for Frame in 1 .. 50 loop
         Files.Folder_Size.Set_Targets (Targets);
         Files.Folder_Size.Step;
         Files.Folder_Size.Take (Path, Result, Available);
         Assert (not Available, "a stalled scan does not publish a partial total");
      end loop;
      Assert (Ada.Calendar.Clock - Before < Prompt_Limit and then Files.Folder_Size.Is_Active
              and then Ada.Directories.Exists (To_String (Started)),
              "repeated frame polling preserves the active helper and never waits for its filesystem work");
      Previous := Started;
      Ada.Directories.Delete_File (Marker);
      Before := Ada.Calendar.Clock;
      Files.Folder_Size.Request (Join (Root, "another-window"));
      --  Retargeting starts a replacement helper: the same headroom as posting.
      Assert (Ada.Calendar.Clock - Before < 2.0, "retargeting does not join the abandoned scan");
      Await_Helper;
      Assert (Started /= Previous, "retargeting starts a separate helper");
      Await_Reaped (Previous);
      Assert (Ada.Directories.Exists (To_String (Started)), "retargeting leaves the replacement helper active");
      Before := Ada.Calendar.Clock;
      Files.Folder_Size.Cancel;
      Files.Folder_Size.Cancel;
      Assert (Ada.Calendar.Clock - Before < Prompt_Limit and then not Files.Folder_Size.Is_Active,
              "repeated cancellation is prompt even while a size read is stalled");
      Await_Reaped (Started);
      Files.Folder_Size.Take (Path, Result, Available);
      Assert (not Available, "cancelled requests never publish stale measurements");
      Ada.Environment_Variables.Clear ("FILES_TEST_STALL_FOLDER_SIZES");
      Ada.Directories.Create_Path (Join (Root, "ready"));
      Write_Binary_File (Join (Join (Root, "ready"), "data"), "12345678");
      Files.Folder_Size.Request (Join (Root, "ready"));
      for Attempt in Files_Suite.Support.Polling loop
         Files.Folder_Size.Step;
         Files.Folder_Size.Take (Path, Result, Available);
         exit when Available;
      end loop;
      --  A fresh request completes normally after a stalled scan was cancelled.
      Files_Suite.Support.Assert_Equal (Available, True, "a measurement after the cancelled scan arrives");
      Files_Suite.Support.Assert_Equal (To_String (Path), Join (Root, "ready"), "it is for the folder asked about");
      Files_Suite.Support.Assert_Equal (Result.Available, True, "it is available");
      Files_Suite.Support.Assert_Equal (Result.Total_Bytes, 8, "its byte total");
      Files_Suite.Support.Assert_Equal (Result.File_Count, 1, "its file count");
      Files.Folder_Size.Take (Path, Result, Available);
      Assert (not Available, "finished measurements are delivered once");
      for Invalid_Target in 1 .. 2 loop
         declare
            Target : constant String :=
              (if Invalid_Target = 1 then Join (Root, "missing") else Join (Join (Root, "ready"), "data"));
         begin
            Files.Folder_Size.Request (Target);
            Files.Folder_Size.Step (Budget => 0);
            Assert (Files.Folder_Size.Is_Active, "zero budget leaves collection for a later frame");
            for Attempt in Files_Suite.Support.Polling loop
               Files.Folder_Size.Step;
               Files.Folder_Size.Take (Path, Result, Available);
               exit when Available;
            end loop;
            Assert (Available and then To_String (Path) = Target and then not Result.Available,
                    "missing and non-directory roots produce unavailable measurements in the helper");
         end;
      end loop;
      Restore;
   exception
      when others => Restore; raise;
   end Test_Folder_Size_Helper_Cancellation;
