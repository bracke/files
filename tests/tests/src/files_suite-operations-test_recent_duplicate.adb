separate (Files_Suite.Operations)
   procedure Test_Recent_Duplicate (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Old_Cwd : constant String := Ada.Directories.Current_Directory;
      Dir_A : constant String := Join (Root, "recent-duplicate-a");
      Dir_B : constant String := Join (Root, "recent-duplicate-b");
      Cwd : constant String := Join (Root, "unrelated-cwd");
      Source_A : constant String := Join (Dir_A, "report.txt");
      Source_B : constant String := Join (Dir_B, "report.txt");
      Existing : constant String := Join (Dir_A, "report (copy).txt");
      Copy_A : constant String := Join (Dir_A, "report (copy 2).txt");
      Copy_B : constant String := Join (Dir_B, "report (copy).txt");
      Bundle : constant String := Join (Dir_B, "bundle");
      Copy_Bundle : constant String := Join (Dir_B, "bundle (copy)");
      Unselected : constant String := Join (Dir_A, "unselected.txt");
   begin
      for Background in Boolean loop
         Reset_Root;
         declare
            Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
            Model : Files.Model.Window_Model;
            Step : Files.Operations.Operation_Result;
            Expected_Rows : Files.Types.String_Vectors.Vector;

            procedure Check_Recent is
            begin
               Assert
                 (Files.Model.In_Recent_View (Model),
                  "Duplicate and history operations retain the complete Recent view: still in Recent");
               Files_Suite.Support.Assert_Equal
                 (Files.Model.Current_Path (Model),
                  "",
                  "Duplicate and history operations retain the complete Recent view: current path");
               Files_Suite.Support.Assert_Equal
                 (Files.Model.Visible_Count (Model),
                  Natural (Expected_Rows.Length),
                  "Duplicate and history operations retain the complete Recent view: visible count");
               for Index in Expected_Rows.First_Index .. Expected_Rows.Last_Index loop
                  Assert (Files.Model.Visible_Item (Model, Index).Full_Path = Expected_Rows.Element (Index),
                          "Recent keeps its order and its unselected rows after helper completion");
               end loop;
               Assert (Files.File_System.Directory_State (Cwd).Entry_Count = 1
                       and then File_Has_Bytes (Join (Cwd, "keep.txt"), "unrelated cwd bytes"),
                       "Duplicate never writes to the process working directory");
            end Check_Recent;

            procedure Check_Copies is
            begin
               Assert (File_Has_Bytes (Copy_A, "source a bytes") and then File_Has_Bytes (Copy_B, "source b bytes"),
                       "same-name Recent files duplicate beside their own sources with independent collision handling");
               Assert (File_Has_Bytes (Join (Copy_Bundle, "payload.txt"), "bundle bytes"),
                       "a Recent directory duplicates beside its source with complete contents");
               Assert
                 (File_Has_Bytes (Existing, "existing copy bytes"),
                  "Duplicate preserves sources, existing copies and unselected items: existing copy");
               Assert
                 (File_Has_Bytes (Source_A, "source a bytes"),
                  "Duplicate preserves sources, existing copies and unselected items: source a");
               Assert
                 (File_Has_Bytes (Source_B, "source b bytes"),
                  "Duplicate preserves sources, existing copies and unselected items: source b");
               Assert
                 (File_Has_Bytes (Unselected, "unselected bytes"),
                  "Duplicate preserves sources, existing copies and unselected items: unselected item");
            end Check_Copies;

            procedure Await_Refresh is
               Applied : Boolean := False;
            begin
               if Background then
                  for Attempt in Files_Suite.Support.Polling loop
                     Applied := Files.Refresh_Jobs.Advance (Model, Settings) or else Applied;
                     exit when not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model));
                  end loop;
                  Assert (Applied and then not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
                          "history refresh applies to the Recent view after a duplicate");
               end if;
            end Await_Refresh;
         begin
            Ada.Directories.Create_Path (Dir_A);
            Ada.Directories.Create_Path (Bundle);
            Ada.Directories.Create_Path (Cwd);
            Write_Binary_File (Source_A, "source a bytes");
            Write_Binary_File (Source_B, "source b bytes");
            Write_Binary_File (Existing, "existing copy bytes");
            Write_Binary_File (Join (Bundle, "payload.txt"), "bundle bytes");
            Write_Binary_File (Unselected, "unselected bytes");
            Write_Binary_File (Join (Cwd, "keep.txt"), "unrelated cwd bytes");
            Files.Settings.Note_Recent (Settings, Source_A);
            Files.Settings.Note_Recent (Settings, Source_B);
            Files.Settings.Note_Recent (Settings, Bundle);
            Files.Settings.Note_Recent (Settings, Unselected);
            Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
            Step := Files.Operations.Navigate_Recent (Model, Settings);
            Files.Model.Select_All_Visible (Model);
            for Index in 1 .. Files.Model.Visible_Count (Model) loop
               Expected_Rows.Append (Files.Model.Visible_Item (Model, Index).Full_Path);
               if Files.Model.Visible_Item (Model, Index).Full_Path = To_Unbounded_String (Unselected) then
                  Files.Model.Toggle_Visible_Selection (Model, Index);
               end if;
            end loop;
            Files_Suite.Support.Assert_Equal
              (Files.Model.Selected_Count (Model),
               3,
               "select files from two folders and one directory");
            Files.Model.Set_Background_Transfers (Model, Background);
            Ada.Directories.Set_Directory (Cwd);
            Step := Files.Operations.Duplicate_Selected (Model, Settings);
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Success,
               "Recent Duplicate starts or completes successfully");
            if Background then
               for Attempt in Files_Suite.Support.Polling loop
                  Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
                  exit when not Files.Model.Paste_Execution_Is_Active (Model);
               end loop;
            end if;
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Success,
               "Recent Duplicate reports success and records all created paths for Undo: status");
            Assert
              (not Files.Model.Paste_Execution_Is_Active (Model),
               "Recent Duplicate reports success and records all created paths for Undo: paste finished");
            Files_Suite.Support.Assert_Equal
              (Files.Model.Last_Error_Key (Model),
               "",
               "Recent Duplicate reports success and records all created paths for Undo: no error");
            Assert
              (Files.Model.Undo_Available (Model),
               "Recent Duplicate reports success and records all created paths for Undo: undo available");
            Check_Recent;
            Check_Copies;
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Success,
               "Undo removes every adjacent copy from its source folder: status");
            Assert
              (not Ada.Directories.Exists (Copy_A),
               "Undo removes every adjacent copy from its source folder: copy A removed");
            Assert
              (not Ada.Directories.Exists (Copy_B),
               "Undo removes every adjacent copy from its source folder: copy B removed");
            Assert
              (not Ada.Directories.Exists (Copy_Bundle),
               "Undo removes every adjacent copy from its source folder: bundle copy removed");
            Await_Refresh;
            Check_Recent;
            Assert (File_Has_Bytes (Existing, "existing copy bytes"), "Undo preserves the pre-existing copy collision");
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Success,
               "Redo re-creates the recorded adjacent destinations");
            Await_Refresh;
            Check_Recent;
            Check_Copies;
            Ada.Directories.Set_Directory (Old_Cwd);
         end;
      end loop;
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Cwd);
         raise;
   end Test_Recent_Duplicate;
