with Files.Settings.Path_References.Testing;
with Files.Preference_Types;
with Hostkit.Path_Text;
with Files.Settings.Path_References;
separate (Files_Suite.Settings)
   --  Forgetting a path and moving it agree on what lies inside it: a root
   --  that ends in a separator ("/") holds everything below it for both, and
   --  a sibling that only shares a folder's name as a prefix is left alone.
   procedure Test_Forget_Follows_The_Move_Rule (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Preference_Types.Color_Label;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Changed  : Boolean;
      Folder   : constant String := Join (Root, "srv");
      Inside   : constant String := Join (Folder, "a.txt");
      Sibling  : constant String := Join (Join (Root, "srv-other"), "b.txt");
      --  The volume root the test tree lies on: "/" or "C:\", ending in a
      --  separator.
      Tree     : constant String := Root;
      Top      : constant String := Tree (Tree'First .. Tree'First + Hostkit.Path_Text.Root_Length (Tree) - 1);
   begin
      Files.Settings.Path_References.Testing.Set_Label (Settings, Inside, Files.Preference_Types.Green);
      Files.Settings.Path_References.Testing.Set_Label (Settings, Sibling, Files.Preference_Types.Red);
      Files.Settings.Path_References.Forget_Path_References (Settings, Folder, Changed);
      Assert (Changed, "forgetting a folder drops what lies inside it");
      Assert
        (Files.Settings.Path_References.Label_Of (Settings, Inside) = Files.Preference_Types.No_Label,
         "a label inside the forgotten folder is gone");
      Assert
        (Files.Settings.Path_References.Label_Of (Settings, Sibling) = Files.Preference_Types.Red,
         "a sibling sharing only the name's prefix keeps its label");
      Assert
        (Top'Length > 0 and then Hostkit.Path_Text.Is_Separator_In (Top, Top (Top'Last)),
         "the root ends in a separator");
      Files.Settings.Path_References.Forget_Path_References (Settings, Top, Changed);
      Assert (Changed, "forgetting the root drops what lies below it");
      Assert
        (Files.Settings.Path_References.Label_Of (Settings, Sibling) = Files.Preference_Types.No_Label,
         "a label below the root is gone, as a move of the root would carry it");
   end Test_Forget_Follows_The_Move_Rule;
