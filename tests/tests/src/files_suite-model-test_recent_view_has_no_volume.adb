separate (Files_Suite.Model)
   --  A folder's volume is sampled for the space bar; the Recent view has no
   --  folder and so no volume: it shows none rather than whatever a capacity
   --  query for an empty path answers (on Windows, the working drive).
   procedure Test_Recent_View_Has_No_Volume (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model;
   begin
      Reset_Root;
      Files.Model.Initialize (Model, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
      Files.Application.Sample_Volume_Space (Model);
      Assert (Files.Model.Volume_Space_Of (Model).Known, "a folder's volume space is known");
      Files.Model.Navigate_Recent (Model, Files.Items.Item_Vectors.Empty_Vector);
      Files.Application.Sample_Volume_Space (Model);
      Assert (not Files.Model.Volume_Space_Of (Model).Known, "the Recent view shows no volume space");
   end Test_Recent_View_Has_No_Volume;
