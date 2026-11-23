with Files.File_Types;
with Files.Model.Info_Pane;
with Files.Model.Creation;
with Files_Suite.Listings;
with Files.Operation_Results;
with Files.Model.Command_Palette;
with Files.Model.Jobs;
separate (Files_Suite.Refresh)
   --  Refresh through the controller. In process (no background transfers:
   --  a helper or the suite) it reads the folder at once, dropping any edit
   --  open -- a new item being named, a rename, the palette -- and the info
   --  pane's scroll with the old listing. In a window (background transfers
   --  on, as the GUI always runs) it reads in the background: the result
   --  waits while an edit is open, lands once it is closed, and keeps the
   --  view's place. A failed refresh keeps the view either way.
   procedure Test_Controller_Refresh_Loading (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      First    : constant String := Join (Root, "first");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (First);
      Write_File (Join (First, "one.txt"));
      Load := Files_Suite.Listings.Load_Directory (First, Settings);
      Files.Model.Initialize (Model, First, Load.Items, First);
      Files_Suite.Support.Discard
        (Files.Controller.Execute_Non_Settings_Command (Files.Commands.Navigate_Home_Command, Model, Settings));
      Write_File (Join (First, "fresh.txt"));
      Files.Model.Creation.Begin_Create_File (Model, "pending.txt", Files.File_Types.Default_Classification);
      Files.Model.Selection.Select_Visible (Model, 3);
      Files.Model.Info_Pane.Scroll_Info_Pane (Model, Lines => 4);
      Files.Model.Command_Palette.Open (Model);
      Result := Files.Controller.Execute_Non_Settings_Command
        (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operation_Results.Operation_Success,
         "refresh operation succeeds");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Path),
         Ada.Directories.Full_Name (First),
         "refresh operation reports current path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model), 2, "an in-process refresh loads the newly created item at once");
      Assert (not Files.Model.Creation.Temporary_Item_Is_Active (Model),
              "an in-process refresh clears temporary create state");
      Assert (not Files.Model.Rename.Is_Active (Model), "an in-process refresh clears rename state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.UI_Types.Focus_None,
         "refresh clears rename focus");
      Assert (not Files.Model.Command_Palette.Is_Open (Model), "refresh clears command palette");
      Assert (not Files.Model.Testing.Selected_Item_Is_Temporary (Model), "refresh clears temporary selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane.Info_Pane_Scroll_Lines (Model),
         0,
         "refresh resets info pane scroll");
      Files.Model.Selection.Select_Visible (Model, 1);
      Files.Model.Selection.Toggle_Visible_Selection (Model, 2);
      Write_File (Join (First, "later.txt"));
      Files.Model.Command_Palette.Open (Model);
      Result := Files.Controller.Execute_Non_Settings_Command
        (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operation_Results.Operation_Success,
         "second refresh operation succeeds");
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 3, "second refresh loads later item");
      Assert
        (Files.Model.Selection.Selected_Count (Model) = 2
         and then Files.Model.Selection.Selected_Name (Model) = "one.txt",
         "synchronous refresh preserves a multi-selection and its primary item by path");

      Project_Tools.Files.Delete_Tree (First);
      Files.Model.Command_Palette.Open (Model);
      Result := Files.Controller.Execute_Non_Settings_Command
        (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operation_Results.Operation_Failed,
         "failed refresh is reported");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Path),
         Ada.Directories.Full_Name (First),
         "failed refresh reports current path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (First),
         "failed refresh preserves path");
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 3, "failed refresh preserves loaded items");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.directory.load",
         "failed refresh records load error");
      Assert (Files.Model.Command_Palette.Is_Open (Model), "failed refresh preserves command palette");
      Ada.Directories.Create_Path (First);
      Write_File (Join (First, "one.txt"));
      Write_File (Join (First, "fresh.txt"));
      Write_File (Join (First, "later.txt"));

      --  In a window.
      Load := Files_Suite.Listings.Load_Directory (First, Settings);
      Files.Model.Initialize (Model, First, Load.Items, First);
      Files.Model.Jobs.Set_Background_Transfers (Model, True);
      Select_Name (Model, "one.txt");
      Files.Model.Info_Pane.Toggle_Info_Pane (Model);
      Files.Model.Info_Pane.Set_Info_Pane_Scroll_Lines (Model, 2);

      --  The palette open while the read runs.
      Write_File (Join (First, "newest.txt"));
      Files.Model.Command_Palette.Open (Model);
      Result := Files.Controller.Execute_Non_Settings_Command
        (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status, Files.Operation_Results.Operation_Success, "a window's refresh starts");
      Assert (Files.Jobs.Process.Active (Files.Model.Jobs.Background_Refresh (Model)),
              "a window's refresh reads in the background");
      Await_Refresh_Ready (Model, "the window's refresh finishes its read");
      Assert (not Files.Refresh.Advance (Model, Settings), "its result is not applied while the palette is open");
      Assert (Files.Model.Command_Palette.Is_Open (Model) and then Files.Model.Item_Count (Model) = 3,
              "the palette stays open over the listing it was opened on");
      Files.Model.Command_Palette.Close (Model);
      Await_View (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model), 4, "the read lands once the palette is closed");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selection.Selected_Name (Model), "one.txt", "keeping the selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane.Info_Pane_Scroll_Lines (Model), 2, "and the info pane's scroll on its item");

      --  A rename open while the read runs.
      Write_File (Join (First, "newer-still.txt"));
      Files.Model.Rename.Toggle (Model);
      Files.Model.Rename.Set_Text (Model, "one-renamed.txt");
      Result := Files.Controller.Execute_Non_Settings_Command
        (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Await_Refresh_Ready (Model, "the refresh under the rename finishes its read");
      Assert (not Files.Refresh.Advance (Model, Settings), "its result is not applied while the rename is open");
      Assert (Files.Model.Rename.Is_Active (Model) and then Files.Model.Rename.Text (Model) = "one-renamed.txt",
              "the rename and its text stay");
      --  Closing the rename is an edit within the view: the read held back
      --  is owed, and the window's poll reads again.
      Files.Model.Rename.Toggle (Model);
      Await_View (Model, Settings);
      Files.Refresh.Resume_Owed (Model, Settings);
      Await_View (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model), 5, "the read lands once the rename is closed");
      Assert (not Files.Model.Refresh_Is_Owed (Model), "with nothing left owed");
      Project_Tools.Files.Delete_Tree (First);
   end Test_Controller_Refresh_Loading;
