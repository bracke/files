with Files_Suite.Listings;
with Files.Operation_Results;
with Files.File_System.Testing;
separate (Files_Suite.Trash)
   procedure Test_Trash_Without_Location (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Trash_Home : constant String := Root & "_xdg_data";
      Trash_File : constant String := Join (Join (Trash_Home, "Trash"), "files");

      procedure Check is
         Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Load     : Files.File_System.Directory_Load_Result;
         Model    : Files.Model.Window_Model;
         Result   : Files.Controller.Controller_Result;
      begin
         Ada.Environment_Variables.Clear ("HOME");
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         Write_File (Join (Root, "nowhere-a.txt"));
         Write_File (Join (Root, "nowhere-b.txt"));
         Load := Files_Suite.Listings.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Set_Filter (Model, "nowhere-");
         Files.Model.Selection.Select_Visible (Model, 1);
         Files.Model.Selection.Toggle_Visible_Selection (Model, 2);
         --  The Finder may take an item without saying where it put it:
         --  the batch still succeeds, with no Undo entry naming an empty
         --  path (which failed the whole Undo), and the user is told.
         Files.File_System.Testing.Trash_Says_Nowhere (True);
         begin
            Result := Files.Controller.Testing.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
         exception
            when others =>
               Files.File_System.Testing.Trash_Says_Nowhere (False);
               raise;
         end;
         Files.File_System.Testing.Trash_Says_Nowhere (False);
         Files_Suite.Support.Assert_Equal
           (Result.Operation.Status,
            Files.Operation_Results.Operation_Success,
            "a trash that keeps no location still trashes the selection");
         Assert (Ada.Directories.Exists (Join (Trash_File, "nowhere-a.txt"))
                 and then Ada.Directories.Exists (Join (Trash_File, "nowhere-b.txt")),
                 "both items are in the trash");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model),
            "undo.partial",
            "the user is told those items cannot be undone");
         Assert (Files.Model.History.Undo_Entries (Model).Is_Empty,
                 "no Undo entry names an empty trashed path");
      end Check;
   begin
      With_Trash_Environment (Check'Access);
   end Test_Trash_Without_Location;
