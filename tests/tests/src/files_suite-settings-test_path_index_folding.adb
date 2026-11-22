with Files.Settings.Path_References.Testing;
with Files.Preference_Types;
with Files.Settings.Path_References;
separate (Files_Suite.Settings)
   procedure Test_Path_Index_Folding (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package Refs renames Files.Settings.Path_References;
      use type Refs.Path_Folding;
      Stored   : constant String := "/home/user/Notes/Plan.txt";
      Shouted  : constant String := "/home/user/NOTES/PLAN.TXT";
      Settings : Files.Settings.Settings_Model;

      --  Label and star Stored afresh under the host rule now in force.
      procedure Store is
      begin
         Settings := Files.Settings.Default_Settings;
         Refs.Testing.Set_Label (Settings, Stored, Files.Preference_Types.Green);
         Refs.Add_Favorite (Settings, Stored);
      end Store;
   begin
      --  A folder decided exactly (a case-sensitive volume) matches its rows
      --  as spelled and nothing else, as asking each path's volume would.
      if Refs.Folding_In ("/home/user") = Refs.Match_Exactly then
         Store;
         declare
            Exact : constant Refs.Path_Index := Refs.Index_Paths (Settings, Refs.Match_Exactly);
         begin
            Files_Suite.Support.Assert_Equal
              (Refs.Label_Of (Exact, Stored), Files.Preference_Types.Green, "an exact folder matches the spelling");
            Assert (Refs.Is_Favorite (Exact, Stored), "and stars it");
            Files_Suite.Support.Assert_Equal
              (Refs.Label_Of (Exact, Shouted), Files.Preference_Types.No_Label,
               "an exact folder does not match another case");
            Assert (not Refs.Is_Favorite (Exact, Shouted), "nor star it");
            Files_Suite.Support.Assert_Equal
              (Refs.Label_Of (Exact, Shouted), Refs.Label_Of (Settings, Shouted),
               "deciding for the folder answers as asking the path does");
         end;
      end if;

      --  Where names fold, the folder decided once matches every spelling.
      Refs.Testing.Simulate_Folding_Host (True);
      Store;
      Assert (Refs.Folding_In ("/home/user") = Refs.Match_Folded, "a folding host decides folded");
      declare
         Folded : constant Refs.Path_Index := Refs.Index_Paths (Settings, Refs.Match_Folded);
         Asking : constant Refs.Path_Index := Refs.Index_Paths (Settings, Refs.Ask_Each_Path);
      begin
         Files_Suite.Support.Assert_Equal
           (Refs.Label_Of (Folded, Shouted), Files.Preference_Types.Green, "a folded folder matches another case");
         Assert (Refs.Is_Favorite (Folded, Shouted), "and stars it");
         Files_Suite.Support.Assert_Equal
           (Refs.Label_Of (Folded, Shouted), Refs.Label_Of (Asking, Shouted),
            "deciding for the folder answers as asking each path does");
      end;
      Refs.Testing.Simulate_Folding_Host (False);
   exception
      when others =>
         Refs.Testing.Simulate_Folding_Host (False);
         raise;
   end Test_Path_Index_Folding;
