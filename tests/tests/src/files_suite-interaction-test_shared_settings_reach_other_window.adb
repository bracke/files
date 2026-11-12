separate (Files_Suite.Interaction)
   --  Two windows share one settings file. A change made in one reaches the
   --  other through Adopt_Shared_Settings: the other's open settings pane
   --  shows it (so a save there cannot revert it, while an edit in progress
   --  survives), and its listing, read with the old hidden-files policy, is
   --  read again.
   procedure Test_Shared_Settings_Reach_Other_Window (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      First_Window    : Files.Model.Window_Model;
      Second_Window   : Files.Model.Window_Model;
      First_Settings  : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Second_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result          : Files.Interaction.Interaction_Result;

      function Shown (Setting : Files.Settings.Scalar_Setting) return String is
        (Ada.Strings.Unbounded.To_String (Files.Model.Settings_Draft_Of (Second_Window).Scalars (Setting)));

      procedure Load (Model : in out Files.Model.Window_Model; Settings : Files.Settings.Settings_Model) is
         Load_Result : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (Files_Suite.Support.Root, Settings);
      begin
         Files.Model.Initialize
           (Model,
            Directory_Path => Files_Suite.Support.Root,
            Items          => Load_Result.Items,
            Home_Path      => "/home/test");
      end Load;
   begin
      Files_Suite.Support.Reset_Root;
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Files_Suite.Support.Root, "Alpha.txt"));
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Files_Suite.Support.Root, ".hidden_one"));
      Load (First_Window, First_Settings);
      Load (Second_Window, Second_Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Second_Window), 1, "the second window lists only the visible file");

      --  The second window has its settings pane open, with an edit of its own.
      Files.Interaction.Execute_Command
        (Second_Window, Second_Settings, "", Files.Commands.Toggle_Settings_Pane_Command, Result => Result);
      Assert (Files.Model.Settings_Pane_Is_Open (Second_Window), "the second window's settings pane is open");
      declare
         Edited : Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Second_Window);
      begin
         Edited.Scalars (Files.Settings.Default_View_Mode_Setting) :=
           Ada.Strings.Unbounded.To_Unbounded_String ("details");
         Files.Model.Set_Settings_Draft (Second_Window, Edited);
      end;

      --  The first window turns hidden files on; the second adopts its settings.
      Files.Interaction.Execute_Command
        (First_Window, First_Settings, "", Files.Commands.Toggle_Hidden_Files_Command, Result => Result);
      Assert (First_Settings.Show_Hidden_Files, "the first window turns hidden files on");
      Files.Interaction.Adopt_Shared_Settings (Second_Window, Second_Settings, First_Settings);

      Assert (Second_Settings.Show_Hidden_Files, "the second window takes the shared settings");
      Files_Suite.Support.Assert_Equal
        (Shown (Files.Settings.Show_Hidden_Files_Setting), "true",
         "the second window's open pane shows the shared change, so its save keeps it");
      Files_Suite.Support.Assert_Equal
        (Shown (Files.Settings.Default_View_Mode_Setting), "details",
         "an edit in progress in the second window's pane survives");
      declare
         Applied : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Apply_Draft (Second_Settings, Files.Model.Settings_Draft_Of (Second_Window));
      begin
         Assert (Applied.Settings.Show_Hidden_Files, "saving the second window's pane does not revert the change");
      end;
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Second_Window), 2,
         "the second window's listing is read again with hidden files shown");

      --  Settings that change neither the listing nor the pane leave both be.
      declare
         Unchanged : constant Files.Settings.Settings_Model := Second_Settings;
      begin
         Files.Interaction.Adopt_Shared_Settings (Second_Window, Second_Settings, Unchanged);
         Files_Suite.Support.Assert_Equal
           (Shown (Files.Settings.Default_View_Mode_Setting), "details",
            "adopting the same settings again keeps the pane's edit");
      end;
   end Test_Shared_Settings_Reach_Other_Window;
