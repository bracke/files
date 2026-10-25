separate (Files_Suite.Model)
   procedure Test_Create_File_Mixed_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Mixed_Model : Files.Model.Window_Model := Sample_Model;
      Mixed_Items : Files.File_System.Item_Vectors.Vector;
      Operation : Files.Operations.Operation_Result;
   begin
      Files.Model.Begin_Create_File (Mixed_Model, "pending.txt");
      Files.Model.Select_Visible_Range
        (Mixed_Model,
         Anchor_Index => Positive (Files.Model.Visible_Count (Mixed_Model)),
         Target_Index => 1);
      Mixed_Items := Files.Model.Selected_Items (Mixed_Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Mixed_Model),
         4,
         "mixed selection includes real items and temporary item");
      Files_Suite.Support.Assert_Equal
        (Natural (Mixed_Items.Length),
         3,
         "selected items excludes the transient create-file item");
      Assert
        (Files.Model.Selection_Includes_Temporary (Mixed_Model),
         "model identifies temporary item inside mixed selection");
      Assert
        (not Files.Model.Selected_Item_Is_Temporary (Mixed_Model),
         "primary selected item need not be temporary in a mixed selection");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Delete_Selected_Items_Command, Mixed_Model),
         "mixed temporary selection does not enable delete");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Open_Selected_Items_Command, Mixed_Model),
         "mixed temporary selection does not enable open");
      Operation := Files.Operations.Open_Selected (Mixed_Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Operation.Status,
         Files.Operations.Operation_Disabled,
         "mixed temporary selection cannot open");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Mixed_Model),
         "error.selection.empty",
         "mixed temporary open records disabled state");
      Operation := Files.Operations.Delete_Selected (Mixed_Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Operation.Status,
         Files.Operations.Operation_Disabled,
         "mixed temporary selection cannot delete");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Mixed_Model),
         "error.selection.empty",
         "mixed temporary delete records disabled state");
   end Test_Create_File_Mixed_Selection;
