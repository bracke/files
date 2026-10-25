separate (Files_Suite.Model)
   --  Going back or forward leaves the view as navigating does: Quick Look
   --  of the old folder's item closes, and recording an Undo step redraws
   --  what Undo and Redo show.
   procedure Test_History_Move_Leaves_View (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model := Sample_Model;
      Content : Files.Quick_Look.Quick_Look_Content;
   begin
      Files.Model.Navigate_To (Model, "/tmp/files_aunit/other", Files.File_System.Item_Vectors.Empty_Vector);
      Files.Model.Open_Quick_Look (Model, Content);
      Assert (Files.Model.Quick_Look_Is_Open (Model), "Quick Look is open");
      Files.Model.Go_Back (Model);
      Assert (not Files.Model.Quick_Look_Is_Open (Model), "going back closes Quick Look of the folder left");

      declare
         Before : constant Natural := Files.Model.Revision (Model);
      begin
         Files.Operations.Record_Undo
           (Model, Files.Model.Undo_Move,
            Files.Types.String_Vectors.Empty_Vector, Files.Types.String_Vectors.Empty_Vector);
         Assert (Files.Model.Revision (Model) /= Before, "recording an Undo step is a change the view redraws");
      end;
   end Test_History_Move_Leaves_View;
