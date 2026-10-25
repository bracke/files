separate (Files_Suite.Operations)
   procedure Test_Background_Operations (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;

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
      Step := Files.Operations.Duplicate_Selected (Model, Settings);
      Finish;
      Files_Suite.Support.Assert_Equal
        (Project_Tools.Files.Read_Raw_File (Join (Root, "a (copy).txt")),
         "needle",
         "background duplicate copies bytes");
      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success and then not Ada.Directories.Exists (Join (Root,
              "a (copy).txt")),
              "background duplicate records Undo on the owning window");
      for Format in Files.Operations.Archive_Format loop
         Select_Name (Model, "a.txt");
         Step := Files.Operations.Compress_Selected (Model, Settings, Format);
         Finish;
         declare
            Archive : constant String :=
              (if Format = Files.Operations.Zip_Archive then "a.zip" else "a.7z");
         begin
            Assert (Ada.Directories.Exists (Join (Root, Archive)),
                    "background compression publishes a complete archive");
            Select_Name (Model, Archive);
            Step := Files.Operations.Extract_Selected (Model, Settings);
            Finish;
            Files_Suite.Support.Assert_Equal
              (Project_Tools.Files.Read_Raw_File (Join (Join (Root, "a"), "a.txt")),
               "needle",
               "background extraction publishes the complete directory");
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Success and then not Ada.Directories.Exists (Join (Root,
                    "a")),
                    "background extraction is undoable");
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then not Ada.Directories.Exists (Join (Root, Archive)),
                    "background archive creation is undoable: " & Archive
                    & " status=" & Files.Operations.Operation_Status'Image (Step.Status)
                    & " error=" & To_String (Step.Error_Key)
                    & " exists=" & Boolean'Image (Ada.Directories.Exists (Join (Root, Archive))));
         end;
      end loop;
      Files.Model.Set_Filter (Model, "needle");
      Step := Files.Operations.Run_Recursive_Search (Model, Settings);
      Finish;
      Assert (Files.Model.Search_Results_Are_Active (Model) and then Files.Model.Item_Count (Model) = 1,
              "background name search returns recursive results");
      Step := Files.Operations.Run_Content_Search (Model, Settings);
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
         Stall : Files_Suite.Support.Environment_Guard;
      begin
         Files_Suite.Support.Save (Stall, "FILES_TEST_STALL_OPERATIONS");
         Ada.Environment_Variables.Set ("FILES_TEST_STALL_OPERATIONS", "1");
         Step := Files.Operations.Duplicate_Selected (Model, Settings);
         declare
            Job : constant Files.Process_Jobs.Session :=
              Files.Model.Background_Operation (Model);
            Marker : constant String := Files.Process_Jobs.Path (Job, "started");
         begin
            for Attempt in Files_Suite.Support.Polling loop
               exit when Ada.Directories.Exists (Marker);
            end loop;
            Assert (Ada.Directories.Exists (Marker),
                    "the duplicate helper reaches the pre-work cancellation point");
         end;
      end;
      Files.Operations.Cancel_Paste_Execution (Model);
      Finish;
      Assert (not Ada.Directories.Exists (Join (Root, "a (copy).txt")),
              "cancellation before work publishes no duplicate");
   exception
      when others =>
         Files.Model.Clear_Paste_Execution (Model);
         raise;
   end Test_Background_Operations;
