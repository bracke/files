package body Files.Operations.Opening.Testing is

   function Detected_Terminal return String
     renames Files.Operations.Opening.Detected_Terminal;

   function Prepare_Open_Selected_Action
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result
     renames Files.Operations.Opening.Prepare_Open_Selected_Action;

   function Execute_Open_Action
     (Action      : Files.Settings.Open_Action;
      Exit_Status : out Integer;
      Failure_Key : out UString;
      Detach      : Boolean := False)
      return Boolean
     renames Files.Operations.Opening.Execute_Open_Action;

   function Open_Action_Executable_Is_Available
     (Action : Files.Settings.Open_Action)
      return Boolean
     renames Files.Operations.Opening.Open_Action_Executable_Is_Available;

end Files.Operations.Opening.Testing;
