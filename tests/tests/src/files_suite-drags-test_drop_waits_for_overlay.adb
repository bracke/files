with Files.Controller.Testing;
with Files.Drop_Events;
with Files.Model.Command_Palette;
with Files.Model.Pasting;
with Files_Suite.Support.Guards;
with Files_Suite.Support.Disk;
separate (Files_Suite.Drags)
   --  A file dropped from the desktop while an overlay owns the input is not
   --  lost: it stays queued while the overlay is open, and is imported once
   --  the overlay closes.
   procedure Test_Drop_Waits_For_Overlay (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Settings    : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source_Path : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "dropped.txt");
      Destination : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "drop-target");
      Model       : aliased Files.Model.Window_Model;
      Paste : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      Queue       : Files.Drop_Events.Drop_Event_Source;
      Paths       : Files.Types.String_Vectors.Vector;
   begin
      Files_Suite.Support.Disk.Reset_Root;
      Ada.Directories.Create_Path (Destination);
      Files_Suite.Support.Disk.Write_File (Source_Path, "dropped bytes");
      Files.Model.Initialize (Model, Destination, Files.Items.Item_Vectors.Empty_Vector, Files_Suite.Support.Disk.Root);
      Paths.Append (To_Unbounded_String (Source_Path));
      Files.Drop_Events.Queue (Queue, Paths);

      Files.Model.Command_Palette.Open (Model);
      Assert (not Files.Controller.Testing.Accepts_Drop_Import (Model), "an open palette does not accept a drop now");
      Files.Controller.Import_Pending_Drops (Model, Settings, Queue);
      Assert (Files.Drop_Events.Has_Pending (Queue), "the drop stays queued while the palette is open");
      Assert (not Files.Model.Foreground_Job_Is_Active (Model)
              and then not Files.Model.Pasting.Conflict_Is_Active (Model),
              "nothing is imported behind the palette");

      Files.Model.Command_Palette.Close (Model);
      Assert (Files.Controller.Testing.Accepts_Drop_Import (Model),
              "with the palette closed the window accepts a drop");
      Files.Controller.Import_Pending_Drops (Model, Settings, Queue);
      Assert (not Files.Drop_Events.Has_Pending (Queue), "the queued drop is taken once the palette closes");
      --  A small drop finishes in the same step; a larger one is still going.
      Assert (Ada.Directories.Exists (Files_Suite.Support.Disk.Join (Destination, "dropped.txt"))
              or else Files.Model.Foreground_Job_Is_Active (Model),
              "and imported through the paste engine");
      Files_Suite.Support.Guards.Release (Paste);
      Files_Suite.Support.Disk.Reset_Root;
   end Test_Drop_Waits_For_Overlay;
