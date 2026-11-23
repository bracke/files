with Files.Settings.Path_References;
with Files.Settings.Path_References.Testing;
with Files.Preference_Types;
with Files.Types;
separate (Files_Suite.Settings)
   --  Two spellings of one path can both be stored (a file written by hand,
   --  a merge of another process's labels). Clearing the path's label
   --  clears every one -- not the first only, leaving the other to show as
   --  if clearing had recoloured the item -- and setting it leaves one.
   procedure Test_Clearing_A_Label_Clears_Every_Spelling (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package Refs renames Files.Settings.Path_References;
      use type Files.Preference_Types.Color_Label;
      Upper    : constant String := Join (Join (Root, "Vol"), "X.txt");
      Lower    : constant String := Join (Join (Root, "vol"), "x.txt");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;

      --  Store both spellings: only a host whose names do not fold can
      --  (a file loaded on a folding host keeps one per path).
      procedure Store_Both is
      begin
         Refs.Testing.Simulate_Folding_Host (False);
         Settings := Files.Settings.Default_Settings;
         Refs.Testing.Set_Label (Settings, Upper, Files.Preference_Types.Red);
         Refs.Testing.Set_Label (Settings, Lower, Files.Preference_Types.Blue);
         Assert (Natural (Refs.Path_Labels (Settings).Length) = 2, "both spellings are stored");
         Refs.Testing.Simulate_Folding_Host (True);
      end Store_Both;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip
           ("Test_Clearing_A_Label_Clears_Every_Spelling", "this host folds names, so it stores one spelling per path");
         return;
      end if;
      Store_Both;
      Refs.Testing.Set_Label (Settings, Upper, Files.Preference_Types.No_Label);
      Assert (Refs.Label_Of (Settings, Lower) = Files.Preference_Types.No_Label
              and then Refs.Path_Labels (Settings).Is_Empty,
              "clearing the label clears every spelling's");

      Store_Both;
      Refs.Testing.Set_Label (Settings, Lower, Files.Preference_Types.Green);
      Assert (Natural (Refs.Path_Labels (Settings).Length) = 1
              and then Refs.Label_Of (Settings, Upper) = Files.Preference_Types.Green,
              "setting it leaves the one label");

      Store_Both;
      Refs.Set_Labels (Settings, Files.Types.String_Vectors.To_Vector (To_Unbounded_String (Lower), 1),
                       Files.Preference_Types.No_Label);
      Assert (Refs.Path_Labels (Settings).Is_Empty, "clearing a selection's labels clears every spelling's");

      Store_Both;
      Refs.Set_Labels (Settings, Files.Types.String_Vectors.To_Vector (To_Unbounded_String (Upper), 1),
                       Files.Preference_Types.Yellow);
      Assert (Natural (Refs.Path_Labels (Settings).Length) = 1
              and then Refs.Label_Of (Settings, Lower) = Files.Preference_Types.Yellow,
              "labelling a selection leaves the one label");
      Refs.Testing.Simulate_Folding_Host (False);
   exception
      when others =>
         Refs.Testing.Simulate_Folding_Host (False);
         raise;
   end Test_Clearing_A_Label_Clears_Every_Spelling;
