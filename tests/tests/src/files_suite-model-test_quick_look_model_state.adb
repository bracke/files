separate (Files_Suite.Model)
   procedure Test_Quick_Look_Model_State (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Quick_Look.Content_Kind;
      Model : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
   begin
      Files_Suite.Support.Select_Name (Model, "Alpha.txt");
      Assert (not Files.Model.Quick_Look_Is_Open (Model), "quick look starts closed");

      Files.Model.Toggle_Quick_Look (Model);
      Assert (Files.Model.Quick_Look_Is_Open (Model), "toggling with a single selection opens quick look");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Quick_Look_Path (Model),
         To_String (Files.Model.Selected_Item (Model).Full_Path),
         "quick look records the previewed item path");
      Assert
        (Files.Model.Quick_Look_Content_Of (Model).Kind = Files.Quick_Look.Info_Content,
         "the pure toggle prepares metadata-only info content");

      declare
         Content  : constant Files.Quick_Look.Quick_Look_Content :=
           (Kind         => Files.Quick_Look.Image_Content,
            Image_Width  => Natural'Last,
            Image_Height => Natural'Last,
            others       => <>);
         Snapshot : Files.Rendering.View_Snapshot;
      begin
         Files.Model.Open_Quick_Look (Model, Content);
         Snapshot := Files.Rendering.Build_Snapshot (Model);
         Assert
           (Snapshot.Quick_Look_Image_Width = 0
              and then Snapshot.Quick_Look_Image_Height = 0,
            "impossible quick-look dimensions are rejected without arithmetic overflow");
      end;

      Files.Model.Toggle_Quick_Look (Model);
      Assert (not Files.Model.Quick_Look_Is_Open (Model), "toggling again closes quick look");

      --  Reopen, then a selection change closes the now-stale preview.
      Files.Model.Toggle_Quick_Look (Model);
      Assert (Files.Model.Quick_Look_Is_Open (Model), "quick look reopens for the current selection");
      Files_Suite.Support.Select_Name (Model, "Beta.txt");
      Assert (not Files.Model.Quick_Look_Is_Open (Model), "changing the selection closes quick look");
   end Test_Quick_Look_Model_State;
