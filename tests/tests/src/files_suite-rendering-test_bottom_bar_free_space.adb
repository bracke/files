separate (Files_Suite.Rendering)
   --  The grouping field (index 9) is laid out as two rows: a label row and a
   --  dedicated segment row spanning the full content width. The five option
   --  segments (None / Type / Modified / Size / Label) therefore sit on their
   --  own row BELOW the label and together span the whole control width (each
   --  roughly a fifth), instead of being squeezed into a partial width shared
   --  with the label. They render even when the field is not the focused one,
   --  so the measured content height -- and thus the scroll bound -- always
   --  accounts for the extra row.
   --  A click on a grouping option segment resolves through the hit-test to that
   --  option (field 9, the clicked option index) at the segment's new row Y --
   --  the same field/option the events layer feeds to Settings_Click -- so
   --  choosing a grouping mode still works after the layout split.
   procedure Test_Bottom_Bar_Free_Space (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      Free_Word : constant String := Files.Localization.Text ("status.free_space.suffix");
      Gib_Unit  : constant String := Files.Localization.Text ("details.size.unit.gib");
      Known     : View_Snapshot := Sample_Snapshot (4, Files.Types.Small_Icons);
      Unknown   : View_Snapshot := Sample_Snapshot (4, Files.Types.Small_Icons);
      Frame     : Frame_Commands;
   begin
      --  A known free-space value renders the "<X GB> free" indicator.
      Known.Free_Space_Known := True;
      Known.Free_Space_Bytes := 3 * 1024 * 1024 * 1024;
      Known.Total_Space_Bytes := 8 * 1024 * 1024 * 1024;
      Frame := Build_Frame_Commands (Known, Width => 1200, Height => 800, Line_Height => 20);
      Assert (Frame_Has_Text (Frame, Free_Word),
              "the bottom bar renders the localized free-space suffix when free space is known");
      Assert (Frame_Has_Text (Frame, Gib_Unit),
              "the free-space indicator formats the value with the shared size unit");

      --  An unknown (unreported) value emits no free-space text at all.
      Unknown.Free_Space_Known := False;
      Unknown.Free_Space_Bytes := 0;
      Frame := Build_Frame_Commands (Unknown, Width => 1200, Height => 800, Line_Height => 20);
      Assert (not Frame_Has_Text (Frame, Free_Word),
              "the bottom bar omits the free-space indicator when the value is unknown");

      declare
         use type Ada.Calendar.Time;
         Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Path     : constant String := Files.Model.Current_Path (Model);
         Now      : constant Ada.Calendar.Time := Ada.Calendar.Clock;
         Space    : constant Files.Model.Volume_Space := (Known => True, Free_Bytes => 100, Total_Bytes => 400);
         Revision : Natural;
      begin
         Assert
           (not Build_Snapshot (Model, Settings).Free_Space_Known,
            "building a snapshot does not query the disk: an unsampled model shows no free space");
         Files.Model.Set_Volume_Space (Model, Path, Space, Now);
         Files_Suite.Support.Assert_Equal
           (Build_Snapshot (Model, Settings).Free_Space_Bytes,
            100,
            "the snapshot shows the sampled free space");
         Assert (Files.Model.Volume_Space_Is_Current (Model, Now), "a fresh sample is current");
         Assert
           (not Files.Model.Volume_Space_Is_Current (Model, Now + 2.0 * Files.Model.Volume_Space_Refresh_Interval),
            "a sample goes stale after the refresh interval");
         Revision := Files.Model.Revision (Model);
         Files.Model.Set_Volume_Space (Model, Path, Space, Now + 1.0);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Revision (Model), Revision, "an unchanged sample does not force a snapshot rebuild");
         Files.Model.Set_Volume_Space (Model, Path & "/different", Space, Now);
         Assert
           (not Files.Model.Volume_Space_Of (Model).Known
            and then not Files.Model.Volume_Space_Is_Current (Model, Now),
            "a sample for another directory is not shown for this one");
      end;
   end Test_Bottom_Bar_Free_Space;
