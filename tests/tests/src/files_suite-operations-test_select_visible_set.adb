separate (Files_Suite.Operations)
   --  Selecting a set of visible rows at once (a marquee drag): exactly those,
   --  repeats once, past-the-end ones skipped, the last one primary, and the
   --  rows as the filter shows them.
   procedure Test_Select_Visible_Set (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
   begin
      Reset_Root;
      for Name of Files.Types.String_Vectors.Vector'
        ([To_Unbounded_String ("apple"), To_Unbounded_String ("banana"), To_Unbounded_String ("cherry"),
          To_Unbounded_String ("apricot")])
      loop
         Write_File (Join (Root, To_String (Name)), "x");
      end loop;
      Files.Model.Initialize (Model, Root, Files.File_System.Load_Directory (Root, Settings).Items, Root);
      Files.Model.Select_Visible (Model, 4);
      Files.Model.Select_Visible_Set (Model, [3, 1, 3, 9]);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 2, "exactly the two rows named");
      Assert (Files.Model.Is_Selected (Model, 1) and then Files.Model.Is_Selected (Model, 3)
              and then not Files.Model.Is_Selected (Model, 4), "the rows named, and not the one before");
      Files_Suite.Support.Assert_Equal
        (To_String (Files.Model.Selected_Item (Model).Name), To_String (Files.Model.Visible_Item (Model, 3).Name),
         "the last one named is primary");

      Files.Model.Set_Filter (Model, "ap");
      Files.Model.Select_Visible_Set (Model, [2]);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 1, "one row under the filter");
      Files_Suite.Support.Assert_Equal
        (To_String (Files.Model.Selected_Item (Model).Name), To_String (Files.Model.Visible_Item (Model, 2).Name),
         "the second row the filter shows");
      Reset_Root;
   end Test_Select_Visible_Set;
