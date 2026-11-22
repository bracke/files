with Files.Rendering.Display_Text;
with Files.Preference_Types;
with Files.File_System_Types;
with Files.Model.Status_Samples;
with Files_Suite.Support.Models;
separate (Files_Suite.Rendering)
   --  The bottom bar shows "<size> free" only when free space is known,
   --  and a snapshot shows the free space the window sampled into the model
   --  (Status_Samples) without querying the disk itself; a sample goes stale
   --  after its refresh interval and belongs to the folder it was taken for.
   procedure Test_Bottom_Bar_Free_Space (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      Free_Word : constant String :=
        Ada.Strings.Fixed.Trim (Files.Localization.Text ("status.free_space", "size", ""), Ada.Strings.Both);
      Known     : View_Snapshot := Sample_Snapshot (4, Files.Preference_Types.Small_Icons);
      Unknown   : View_Snapshot := Sample_Snapshot (4, Files.Preference_Types.Small_Icons);
      Frame     : Frame_Commands;
   begin
      --  A known free-space value renders the "<X GB> free" indicator.
      Known.Free_Space_Known := True;
      Known.Free_Space_Bytes := 3 * 1024 * 1024 * 1024;
      Known.Total_Space_Bytes := 8 * 1024 * 1024 * 1024;
      Frame := Build_Frame_Commands (Known, Width => 1200, Height => 800, Line_Height => 20);
      Assert (Frame_Has_Text (Frame, Free_Word),
              "the bottom bar renders the localized free-space suffix when free space is known");
      Assert (Frame_Has_Text (Frame, Files.Rendering.Display_Text.Size_Text (Known.Free_Space_Bytes)),
              "the free-space indicator formats the value as every size is formatted");

      --  An unknown (unreported) value emits no free-space text at all.
      Unknown.Free_Space_Known := False;
      Unknown.Free_Space_Bytes := 0;
      Frame := Build_Frame_Commands (Unknown, Width => 1200, Height => 800, Line_Height => 20);
      Assert (not Frame_Has_Text (Frame, Free_Word),
              "the bottom bar omits the free-space indicator when the value is unknown");

      declare
         use type Ada.Calendar.Time;
         Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
         Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Path     : constant String := Files.Model.Current_Path (Model);
         Now      : constant Ada.Calendar.Time := Ada.Calendar.Clock;
         Space    : constant Files.File_System_Types.Volume_Space := (Known => True, Free_Bytes => 100, Total_Bytes =>
           400);
         Revision : Natural;
      begin
         Assert
           (not Build_Snapshot (Model, Settings).Free_Space_Known,
            "building a snapshot does not query the disk: an unsampled model shows no free space");
         Files.Model.Status_Samples.Set_Volume_Space (Model, Path, Space, Now);
         Files_Suite.Support.Assert_Equal
           (Build_Snapshot (Model, Settings).Free_Space_Bytes,
            100,
            "the snapshot shows the sampled free space");
         Assert (Files.Model.Status_Samples.Volume_Space_Is_Current (Model, Now), "a fresh sample is current");
         Assert
           (not Files.Model.Status_Samples.Volume_Space_Is_Current
              (Model, Now + 2.0 * Files.Model.Status_Samples.Volume_Space_Refresh_Interval),
            "a sample goes stale after the refresh interval");
         Revision := Files.Model.Revision (Model);
         Files.Model.Status_Samples.Set_Volume_Space (Model, Path, Space, Now + 1.0);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Revision (Model), Revision, "an unchanged sample does not force a snapshot rebuild");
         Files.Model.Status_Samples.Set_Volume_Space (Model, Path & "/different", Space, Now);
         Assert
           (not Files.Model.Status_Samples.Volume_Space_Of (Model).Known
            and then not Files.Model.Status_Samples.Volume_Space_Is_Current (Model, Now),
            "a sample for another directory is not shown for this one");
      end;
   end Test_Bottom_Bar_Free_Space;
