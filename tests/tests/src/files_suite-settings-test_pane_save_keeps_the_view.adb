with Files.Interaction.Testing;
with Files.Interaction;
with Files.Overlays.Settings_Form;
with Files.Model.Filtering;
with Files.Model.Folder_Sizes;
with Files.Model.Jobs;
with Files.Model.Selection;
with Files.Folder_Size;
with Files.Jobs.Process;
with Files_Suite.Listings;
separate (Files_Suite.Settings)
   --  Saving in the settings pane changes the view only as far as the
   --  saved settings say -- as another window's change does: in a window
   --  (background transfers on, as the GUI always runs) a save that touches
   --  nothing listed reads nothing again, search results take the hidden
   --  filter in place, and a folder read again for it keeps its measured
   --  folder sizes.
   procedure Test_Pane_Save_Keeps_The_View (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path     : constant String := Join (Root, "pane.conf");
      Folder   : constant String := Join (Root, "folder");
      Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;

      function Background_Read return Boolean is
        (Files.Jobs.Process.Active (Files.Model.Jobs.Background_Refresh (Model)));

      --  Flip a boolean setting in the open pane's draft and save it.
      procedure Save_Flipped (Setting : Files.Settings.Scalar_Setting) is
         Draft : Files.Settings.Settings_Draft := Files.Model.Settings_Pane.Draft_Of (Model);
      begin
         Draft.Scalars (Setting) :=
           To_Unbounded_String
             (if Files.Settings.Testing.Scalar_Text (Settings, Setting) = "true" then "false" else "true");
         Files.Overlays.Settings_Form.Set_Draft (Model, Draft);
         Files.Interaction.Testing.Execute_Command
           (Model, Settings, Path, Files.Commands.Save_Settings_Command, Result => Result);
      end Save_Flipped;

      procedure Measure_Folder is
         Measured : Files.Folder_Size.Measurement_Vectors.Vector;
      begin
         Measured.Append
           (Files.Folder_Size.Measurement'
              (Path   => To_Unbounded_String (Folder),
               Result => (Available => True, Total_Bytes => 7, File_Count => 1, Item_Count => 1, Capped => False),
               others => <>));
         Files.Model.Folder_Sizes.Note (Model, Measured);
      end Measure_Folder;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Folder);
      Write_File (Join (Root, "Alpha.txt"));
      Write_File (Join (Root, ".hidden"));
      declare
         Load : constant Files.File_System.Directory_Load_Result :=
           Files_Suite.Listings.Load_Directory (Root, Settings);
      begin
         Files.Model.Initialize (Model, Root, Load.Items, Root);
      end;
      Files.Model.Jobs.Set_Background_Transfers (Model, True);
      Files.Model.Filtering.Set_Filter (Model, "a");
      Files.Model.Filtering.Note_Search_Results (Model, Files.UI_Types.Search_Names, "a");
      Select_Name (Model, "folder");
      Measure_Folder;
      Assert (Files.Model.Folder_Sizes.Cached_For (Model, Folder), "the selected folder's size is measured");
      Files.Overlays.Settings_Form.Begin_Edit (Model, Settings);

      --  A setting nothing listed depends on.
      Save_Flipped (Files.Settings.Show_File_Extensions_Setting);
      Assert (Ada.Directories.Exists (Path), "the save is written");
      Assert (Files.Model.Filtering.Search_Results_Are_Active (Model), "the search results stay shown");
      Assert (not Background_Read, "and nothing is read again");
      Assert (Files.Model.Folder_Sizes.Cached_For (Model, Folder), "the measured folder size stays");

      --  The hidden filter: the results take it in place.
      Save_Flipped (Files.Settings.Show_Hidden_Files_Setting);
      Assert (Settings.Show_Hidden_Files, "hidden files are shown now");
      Assert (Files.Model.Filtering.Search_Results_Are_Active (Model), "the results stay shown through it");
      Assert (not Background_Read, "taking it in place, with nothing read again");
      Assert (Files.Model.Folder_Sizes.Cached_For (Model, Folder), "the folder size still stays");

      --  A folder is read again for the hidden filter, its sizes kept.
      Files.Model.Filtering.Clear_Filter (Model);
      Save_Flipped (Files.Settings.Show_Hidden_Files_Setting);
      Assert (not Settings.Show_Hidden_Files, "hidden files are hidden again");
      Assert (Background_Read, "the folder is read again for it, in the background");
      Assert (Files.Model.Folder_Sizes.Cached_For (Model, Folder), "and its measured sizes stay");
      Files.Model.Selection.Clear (Model);
      Reset_Root;
   end Test_Pane_Save_Keeps_The_View;
