with Files.UI_Types;
with Files.Model.Jobs;
with Files.Model.Testing;
with Files.Operation_Results;
with Files.Operation_Commands;
with Files_Suite.Support.Guards;
with Files_Suite.Support.Timing;
separate (Files_Suite.Recovery)
   procedure Test_Background_Operations (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : aliased Files.Model.Window_Model;
      Paste : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operation_Results.Operation_Result;

      procedure Finish is
      begin
         Finish_Background_Operation (Model, Settings, Step);
      end Finish;
   begin
      Reset_Root;
      Write_Binary_File (Join (Root, "a.txt"), "needle");
      Ada.Directories.Create_Directory (Join (Root, "nested"));
      Write_Binary_File (Join (Join (Root, "nested"), "needle-name.txt"), "needle");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Background_Transfers (Model, True);
      Select_Name (Model, "a.txt");
      Step := Files.Operation_Commands.Duplicate_Selected (Model, Settings);
      --  An operation is the window's modal job in its own right, not a paste.
      Assert (Files.Model."=" (Files.Model.Foreground_Job (Model), Files.Model.Operation_Job)
              and then not Files.Model.Pasting.Execution_Is_Active (Model),
              "a background operation runs as the modal operation job, not as a paste");
      Files_Suite.Support.Assert_Equal
        (To_String (Files.Model.Jobs.Foreground_Progress_Of (Model).Label_Key), "command.file.duplicate",
         "its progress shows its command");
      Finish;
      Files_Suite.Support.Assert_Equal
        (Project_Tools.Files.Read_Raw_File (Join (Root, "a (copy).txt")),
         "needle",
         "background duplicate copies bytes");
      Step := Complete_Operation
                       (Model, Settings, Files.Operation_Commands.Undo_Last (Model, Settings));
      Assert (Step.Status = Files.Operation_Results.Operation_Success and then not Ada.Directories.Exists (Join (Root,
              "a (copy).txt")),
              "background duplicate records Undo on the owning window");
      for Format in Files.Operations.Archive_Format loop
         Select_Name (Model, "a.txt");
         Step := Files.Operation_Commands.Compress_Selected (Model, Settings, Format);
         Finish;
         declare
            Archive : constant String :=
              (if Format = Files.Operations.Zip_Archive then "a.zip" else "a.7z");
         begin
            Assert (Ada.Directories.Exists (Join (Root, Archive)),
                    "background compression publishes a complete archive");
            Select_Name (Model, Archive);
            Step := Files.Operation_Commands.Extract_Selected (Model, Settings);
            Finish;
            Files_Suite.Support.Assert_Equal
              (Project_Tools.Files.Read_Raw_File (Join (Join (Root, "a"), "a.txt")),
               "needle",
               "background extraction publishes the complete directory");
            Step := Complete_Operation
                       (Model, Settings, Files.Operation_Commands.Undo_Last (Model, Settings));
            Assert (Step.Status = Files.Operation_Results.Operation_Success
                    and then not Ada.Directories.Exists (Join (Root, "a")),
                    "background extraction is undoable");
            Step := Complete_Operation
                       (Model, Settings, Files.Operation_Commands.Undo_Last (Model, Settings));
            Assert (Step.Status = Files.Operation_Results.Operation_Success
                    and then not Ada.Directories.Exists (Join (Root, Archive)),
                    "background archive creation is undoable: " & Archive
                    & " status=" & Files.Operation_Results.Operation_Status'Image (Step.Status)
                    & " error=" & To_String (Step.Error_Key)
                    & " exists=" & Boolean'Image (Ada.Directories.Exists (Join (Root, Archive))));
         end;
      end loop;
      Files.Model.Set_Filter (Model, "needle");
      Step := Files.Operation_Commands.Run_Search (Model, Settings, Files.UI_Types.Search_Names);
      Finish;
      Assert (Files.Model.Search_Results_Are_Active (Model) and then Files.Model.Item_Count (Model) = 1,
              "background name search returns recursive results");
      Step := Files.Operation_Commands.Run_Search (Model, Settings, Files.UI_Types.Search_Contents);
      Finish;
      Assert (Files.Model.Search_Results_Are_Active (Model),
              "background content search returns matches regardless of filename: search results active");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         2,
         "background content search returns matches regardless of filename: item count");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Model),
         2,
         "background content search returns matches regardless of filename: visible count");
      Files.Model.Set_Filter (Model, "");
      Step := Files.Operations.Refresh (Model, Settings);
      Select_Name (Model, "a.txt");
      declare
         --  The helper stalls for this duplicate only; the guard puts the
         --  variable back before the cancellation, on failure too.
         Stall : Files_Suite.Support.Guards.Environment_Guard;
      begin
         Files_Suite.Support.Guards.Save (Stall, "FILES_TEST_STALL_OPERATIONS");
         Ada.Environment_Variables.Set ("FILES_TEST_STALL_OPERATIONS", "1");
         Step := Files.Operation_Commands.Duplicate_Selected (Model, Settings);
         declare
            Job : constant Files.Jobs.Process.Session :=
              Files.Model.Jobs.Background_Operation (Model);
            Marker : constant String := Files.Jobs.Process.Path (Job, "started");
         begin
            for Attempt in Files_Suite.Support.Timing.Polling loop
               exit when Ada.Directories.Exists (Marker);
            end loop;
            Assert (Ada.Directories.Exists (Marker),
                    "the duplicate helper reaches the pre-work cancellation point");
         end;
      end;
      Files.Job_Drivers.Foreground.Cancel (Model);
      Finish;
      Assert (not Ada.Directories.Exists (Join (Root, "a (copy).txt")),
              "cancellation before work publishes no duplicate");
   end Test_Background_Operations;
