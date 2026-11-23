with Files.Drop_Events;
with Files.File_System_Types;
with Files.Model.Info_Pane;
with Files.Model.Jobs;
with Files.Preference_Types;
with Files.Settings.Path_References;
with Files.Settings.Path_References.Testing;
with Files_Suite.Listings;
with Files_Suite.Support.Guards;
with Files_Suite.Support.Disk;
separate (Files_Suite.Drags)
   --  A drop from the desktop ends the way every dispatch does
   --  (Controller.Finish_Dispatch): the moved item's label follows it into
   --  the settings file, and the selected item's details are read.
   procedure Test_Drop_Finishes_Dispatch (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      use type Files.Preference_Types.Color_Label;
      Root          : constant String := Files_Suite.Support.Disk.Root;
      Source_Path   : constant String := Files_Suite.Support.Disk.Join (Root, "dropped.txt");
      Destination   : constant String := Files_Suite.Support.Disk.Join (Root, "drop-target");
      Moved_Path    : constant String := Files_Suite.Support.Disk.Join (Destination, "dropped.txt");
      Settings_Path : constant String := Files_Suite.Support.Disk.Join (Root, "settings.conf");
      Settings      : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model         : aliased Files.Model.Window_Model;
      Paste         : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      Queue         : Files.Drop_Events.Drop_Event_Source;
      Paths         : Files.Types.String_Vectors.Vector;
      Result        : Files.Interaction.Interaction_Result;
   begin
      Files_Suite.Support.Disk.Reset_Root;
      Ada.Directories.Create_Path (Destination);
      Files_Suite.Support.Disk.Write_File (Source_Path, "dropped bytes");
      Files_Suite.Support.Disk.Write_File (Files_Suite.Support.Disk.Join (Destination, "notes.txt"), "notes");
      Files.Settings.Path_References.Testing.Set_Label (Settings, Source_Path, Files.Preference_Types.Red);
      Files.Model.Initialize
        (Model, Destination,
         Files_Suite.Listings.Load_Directory (Destination, Files.Settings.Default_Settings).Items, Root);
      Files.Model.Info_Pane.Toggle_Info_Pane (Model);
      Paths.Append (To_Unbounded_String (Source_Path));
      Files.Drop_Events.Queue (Queue, Paths, Files.File_System_Types.Drop_Move);

      Files.Interaction.Import_Drops (Model, Settings, Settings_Path, Queue, Result);
      Assert (not Files.Drop_Events.Has_Pending (Queue), "the drop is taken");
      Assert (not Files.Model.Jobs.Foreground_Job_Is_Active (Model)
              and then Ada.Directories.Exists (Moved_Path)
              and then not Ada.Directories.Exists (Source_Path),
              "a small move drop finishes in the same step");
      Assert (Result.Settings_Changed, "the drop's dispatch reports the settings it saved");
      Assert (Files.Settings.Path_References.Label_Of (Settings, Moved_Path) = Files.Preference_Types.Red
              and then Files.Settings.Path_References.Label_Of (Settings, Source_Path)
                         = Files.Preference_Types.No_Label,
              "the moved item's label follows it");
      Assert (Ada.Directories.Exists (Settings_Path), "and is written to the settings file");
      --  The drop's reload leaves nothing selected. A drop refused (its
      --  source is gone) keeps the selection, and its dispatch still ends by
      --  reading the selected item's details.
      Assert (Files.Model.Selection.Select_By_Name (Model, "notes.txt"), "the folder's own file is listed");
      Assert (Files.Model.Info_Pane.Selected_Item_Needs_Extra (Model), "its details are not read yet");
      Paths.Clear;
      Paths.Append (To_Unbounded_String (Files_Suite.Support.Disk.Join (Root, "gone.txt")));
      Files.Drop_Events.Queue (Queue, Paths, Files.File_System_Types.Drop_Copy);
      Files.Interaction.Import_Drops (Model, Settings, Settings_Path, Queue, Result);
      Assert (not Files.Drop_Events.Has_Pending (Queue), "the refused drop is taken");
      Assert (Files.Model.Selection.Selected_Count (Model) = 1, "the refused drop keeps the selection");
      Assert (not Files.Model.Info_Pane.Selected_Item_Needs_Extra (Model),
              "and its dispatch reads the selected item's details");
      Files_Suite.Support.Guards.Release (Paste);
      Files_Suite.Support.Disk.Reset_Root;
   end Test_Drop_Finishes_Dispatch;
