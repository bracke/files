package body Files.Operations.Opening.Testing is

   function Detected_Terminal return String
     renames Files.Operations.Opening.Detected_Terminal;

   function Prepare_Open_Selected_Action
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result
     renames Files.Operations.Opening.Prepare_Open_Selected_Action;

end Files.Operations.Opening.Testing;
