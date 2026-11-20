with Files.Input_Actions;
with Files.Settings.Path_References;
with Files_Suite.Support.Disk;
use Files.Settings.Path_References;
separate (Files_Suite.Interaction)
   procedure Test_Favorite_Group_Toggle_Multi_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Dir      : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "fav-group");
      One      : constant String := Files_Suite.Support.Disk.Join (Dir, "one.txt");
      Two      : constant String := Files_Suite.Support.Disk.Join (Dir, "two.txt");
      Three    : constant String := Files_Suite.Support.Disk.Join (Dir, "three.txt");
      Model    : Files.Model.Window_Model;
      Action   : constant Files.Input_Actions.Input_Action :=
        (Kind    => Files.Input_Actions.Command_Input_Action,
         Command => Files.Commands.Toggle_Favorite_Command);
   begin
      Files_Suite.Support.Disk.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Disk.Write_File (One, "a");
      Files_Suite.Support.Disk.Write_File (Two, "b");
      Files_Suite.Support.Disk.Write_File (Three, "c");

      --  All three selected, none favorited: one invocation stars every item.
      Model := Loaded_Model (Dir);
      Files.Model.Selection.Select_All_Visible (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selection.Selected_Count (Model),
         3,
         "all three files are selected before the group toggle");
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "", Action, Guikit.Input.No_Modifiers, Result);
      Assert (Is_Favorite (Settings, One), "the group toggle stars the first item");
      Assert (Is_Favorite (Settings, Two), "the group toggle stars the second item");
      Assert (Is_Favorite (Settings, Three), "the group toggle stars the third item");
      Assert (Result.Settings_Changed, "starring the group reports a settings change");

      --  All three favorited: the next invocation un-stars the whole group.
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "", Action, Guikit.Input.No_Modifiers, Result);
      Assert (not Is_Favorite (Settings, One), "a second group toggle un-stars the first item");
      Assert (not Is_Favorite (Settings, Two), "a second group toggle un-stars the second item");
      Assert (not Is_Favorite (Settings, Three), "a second group toggle un-stars the third item");

      --  Mixed selection (one already favorited): the group toggle stars every
      --  item rather than flipping each independently.
      Files.Settings.Path_References.Toggle_Favorite_Path (Settings, Two);
      Assert (Is_Favorite (Settings, Two), "the second item is pre-favorited for the mixed case");
      Files.Interaction.Apply_Input_Action
        (Model, Settings, "", Action, Guikit.Input.No_Modifiers, Result);
      Assert (Is_Favorite (Settings, One), "a mixed group toggle stars the previously unstarred first item");
      Assert (Is_Favorite (Settings, Two), "a mixed group toggle leaves the already-starred second item starred");
      Assert (Is_Favorite (Settings, Three), "a mixed group toggle stars the previously unstarred third item");
   end Test_Favorite_Group_Toggle_Multi_Selection;
