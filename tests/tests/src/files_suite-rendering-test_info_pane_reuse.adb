with Ada.Calendar;
with Files.File_System_Types;
with Files.Model.Clipboard;
with Files.Model.Info_Pane;
with Files.Model.Ownership_Input;
with Files.Model.Status_Samples;
with Files.Model.Testing;
with Files_Suite.Support.Models;
separate (Files_Suite.Rendering)
   --  A build that keeps the rows keeps the info pane's rows too while what
   --  they were built from (Info_Pane_Key) stands: a header-only change
   --  formats nothing again. Each input of that key, changed alone, has the
   --  pane built again.
   procedure Test_Info_Pane_Reuse (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Ada.Calendar.Time;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Snapshot : Files.Rendering.View_Snapshot;
      Now      : Ada.Calendar.Time := Ada.Calendar.Clock;
      Mark     : constant String := "kept-mark";

      --  Put the mark on the pane's first row, as a kept row would carry it.
      procedure Put_Mark is
         Row : Files.Rendering.Info_Snapshot;
      begin
         Assert (not Snapshot.Selected_Info.Is_Empty, "the pane lists the selection");
         Row := Snapshot.Selected_Info.First_Element;
         Row.Name := To_Unbounded_String (Mark);
         Snapshot.Selected_Info.Replace_Element (Snapshot.Selected_Info.First_Index, Row);
      end Put_Mark;

      --  Build again, keeping the rows, at Now.
      procedure Rebuild is
      begin
         Files.Rendering.Build_Snapshot_Into (Snapshot, Model, Settings, Now, Keep_Rows => True);
      end Rebuild;

      function Kept return Boolean is
        (not Snapshot.Selected_Info.Is_Empty
         and then To_String (Snapshot.Selected_Info.First_Element.Name) = Mark);

      --  Change one input alone and check the pane was built again; then
      --  mark the new rows for the next step.
      procedure Expect_Rebuilt (Step : String; Change : not null access procedure) is
      begin
         Put_Mark;
         Change.all;
         Rebuild;
         Assert (not Kept, Step & ": the info pane is built again");
      end Expect_Rebuilt;

      procedure Select_Other is
      begin
         Files_Suite.Support.Models.Select_Name (Model, "Beta.txt");
      end Select_Other;

      procedure Cut is
         Paths : Files.Types.String_Vectors.Vector;
      begin
         Paths.Append (To_Unbounded_String ("/sample/cut"));
         Files.Model.Clipboard.Set (Model, Paths, Files.Model.Clipboard_Cut);
      end Cut;

      procedure Measure is
      begin
         Files.Model.Testing.Set_Folder_Size
           (Model, "/sample/measured", (Available => True, Total_Bytes => 42, others => <>));
      end Measure;

      procedure Settings_Changed is
      begin
         Files.Model.Note_Settings_Changed (Model);
      end Settings_Changed;

      procedure Account_Sampled is
      begin
         Files.Model.Status_Samples.Set_Account_Name (Model, Files.File_System_Types.User_Account, 4_243, "probe");
      end Account_Sampled;

      procedure Next_Minute is
      begin
         Now := Now + 61.0;
      end Next_Minute;

      procedure Reopened is
      begin
         Files.Model.Info_Pane.Toggle_Info_Pane (Model);
         Rebuild;
         Files.Model.Info_Pane.Toggle_Info_Pane (Model);
      end Reopened;
   begin
      Files_Suite.Support.Models.Select_Name (Model, "Alpha.txt");
      Files.Model.Info_Pane.Toggle_Info_Pane (Model);
      Files.Rendering.Build_Snapshot_Into (Snapshot, Model, Settings, Now);

      --  A change the pane does not show keeps its rows.
      Put_Mark;
      Files.Model.Set_Error (Model, "error.probe.kept");
      Rebuild;
      Assert (Kept, "a header-only change keeps the info pane's rows");
      Rebuild;
      Assert (Kept, "and so does a build with nothing changed");

      Expect_Rebuilt ("the selection", Select_Other'Access);
      Expect_Rebuilt ("the rows", Cut'Access);
      Expect_Rebuilt ("a folder size", Measure'Access);
      Expect_Rebuilt ("the settings", Settings_Changed'Access);
      Expect_Rebuilt ("an account name", Account_Sampled'Access);
      Expect_Rebuilt ("the minute", Next_Minute'Access);
      Expect_Rebuilt ("the pane closed and opened", Reopened'Access);

      --  An ownership edit shows its buffer in the pane: never kept.
      Put_Mark;
      Files.Model.Ownership_Input.Focus_Ownership_Input (Model, Editing_Group => False, Account_Name => "probe");
      if Files.Model.Focus (Model) = Files.UI_Types.Focus_Ownership_Input then
         Rebuild;
         Assert (not Kept, "an ownership edit: the info pane is built again");
         Put_Mark;
         Rebuild;
         Assert (not Kept, "and again on every build while it lasts");
      end if;
   end Test_Info_Pane_Reuse;
