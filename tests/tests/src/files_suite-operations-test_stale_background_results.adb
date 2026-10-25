separate (Files_Suite.Operations)
   procedure Test_Stale_Background_Results (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
      Other    : constant String := Join (Root, "other-view");

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
      Step := Files.Operations.Refresh (Model, Settings);
      Await_View (Model, Settings);
      Select_Name (Model, "a.txt");
      Ada.Directories.Create_Directory (Other);
      Write_Binary_File (Join (Other, "other.txt"), "other");
      Step := Files.Operations.Duplicate_Selected (Model, Settings);
      declare
         Job : constant Files.Process_Jobs.Session :=
           Files.Model.Background_Operation (Model);
         Finished, Cancelled : Boolean;
      begin
         for Attempt in Files_Suite.Support.Polling loop
            Files.Process_Jobs.Poll (Job, Finished, Cancelled);
            exit when Finished;
         end loop;
         Assert (Finished and then not Cancelled,
                 "the duplicate result is ready before the view changes");
      end;
      Load := Files.File_System.Load_Directory (Other, Settings);
      Files.Model.Navigate_To (Model, Other, Load.Items);
      Finish;
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Other,
         "a completed operation cannot replace a newer directory view with its old snapshot: current path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         1,
         "a completed operation cannot replace a newer directory view with its old snapshot: item count");
      Files_Suite.Support.Assert_Equal
        (To_String (Files.Model.Visible_Item (Model, 1).Name),
         "other.txt",
         "a completed operation cannot replace a newer directory view with its old snapshot: listed item");
      Assert
        (Ada.Directories.Exists (Join (Root, "a (copy).txt"))
         and then Files.Model.Undo_Available (Model),
         "the stale-view duplicate still publishes its file and recoverable history");
      Step := Complete_Operation
        (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Await_View (Model, Settings);
      Assert
        (not Ada.Directories.Exists (Join (Root, "a (copy).txt")),
         "undoing the stale-view operation leaves the newer directory view intact: copy removed");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Other,
         "undoing the stale-view operation leaves the newer directory view intact: current path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         1,
         "undoing the stale-view operation leaves the newer directory view intact: item count");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Navigate_To (Model, Root, Load.Items);

      Select_Name (Model, "a.txt");
      Step := Files.Operations.Duplicate_Selected (Model, Settings);
      declare
         Job : constant Files.Process_Jobs.Session :=
           Files.Model.Background_Operation (Model);
         Finished, Cancelled : Boolean;
      begin
         for Attempt in Files_Suite.Support.Polling loop
            Files.Process_Jobs.Poll (Job, Finished, Cancelled);
            exit when Finished;
         end loop;
         Assert (Finished and then not Cancelled,
                 "the duplicate result is ready before the round-trip navigation");
      end;
      Load := Files.File_System.Load_Directory (Other, Settings);
      Files.Model.Navigate_To (Model, Other, Load.Items);
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Navigate_To (Model, Root, Load.Items);
      Files.Model.Begin_Create_File (Model, "pending.txt");
      Files.Model.Set_Error (Model, "error.trash.restore_exists");
      Finish;
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "an old result cannot overwrite a newer incarnation of the same directory view: current path");
      Assert
        (Files.Model.Temporary_Item_Is_Active (Model),
         "an old result cannot overwrite a newer incarnation of the same directory view: temporary item active");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.trash.restore_exists",
         "an old result cannot overwrite a newer incarnation of the same directory view: error key");
      Assert
        (Ada.Directories.Exists (Join (Root, "a (copy).txt"))
         and then Files.Model.Undo_Available (Model),
         "the round-trip stale result retains its file and Undo history");
      Files.Model.Cancel_Create_File (Model);
      Step := Complete_Operation
        (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Await_View (Model, Settings);
      Assert
        (not Ada.Directories.Exists (Join (Root, "a (copy).txt")),
         "the round-trip stale operation remains safely undoable");

      Select_Name (Model, "a.txt");
      Step := Files.Operations.Delete_Selected (Model, Settings);
      declare
         Job : constant Files.Process_Jobs.Session :=
           Files.Model.Background_Operation (Model);
         Finished, Cancelled : Boolean;
      begin
         for Attempt in Files_Suite.Support.Polling loop
            Files.Process_Jobs.Poll (Job, Finished, Cancelled);
            exit when Finished;
         end loop;
         Assert (Finished and then not Cancelled,
                 "the destructive result is ready before the view changes");
      end;
      Load := Files.File_System.Load_Directory (Other, Settings);
      Files.Model.Navigate_To (Model, Other, Load.Items);
      Files.Model.Begin_Create_File (Model, "pending.txt");
      Files.Model.Set_Error (Model, "error.trash.restore_exists");
      Finish;
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Other,
         "an old destructive result cannot refresh or alter newer view state: current path");
      Assert
        (Files.Model.Temporary_Item_Is_Active (Model),
         "an old destructive result cannot refresh or alter newer view state: temporary item active");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.trash.restore_exists",
         "an old destructive result cannot refresh or alter newer view state: error key");
      Assert
        (not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
         "an old destructive result cannot refresh or alter newer view state: no refresh started");
      Assert
        (not Ada.Directories.Exists (Join (Root, "a.txt"))
         and then Files.Model.Undo_Available (Model),
         "the stale-view destructive result retains its mutation and Undo history");
      Files.Model.Cancel_Create_File (Model);
      Step := Complete_Operation
        (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Await_View (Model, Settings);
      Assert
        (Ada.Directories.Exists (Join (Root, "a.txt")),
         "undoing the stale destructive result leaves the newer view intact: original restored");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Other,
         "undoing the stale destructive result leaves the newer view intact: current path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         1,
         "undoing the stale destructive result leaves the newer view intact: item count");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Navigate_To (Model, Root, Load.Items);
   exception
      when others =>
         Files.Model.Clear_Paste_Execution (Model);
         raise;
   end Test_Stale_Background_Results;
