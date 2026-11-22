with Files.Model;
with Files.Settings;
with Guikit.Input;

--  Test access to Files.Operations.Opening's private part.
package Files.Operations.Opening.Testing is

   --  @return Files.Operations.Opening.Detected_Terminal.
   function Detected_Terminal return String;

   --  Files.Operations.Opening.Prepare_Open_Selected_Action.
   --  @param Model Window model to inspect.
   --  @param Settings Settings model used for open-action lookup.
   --  @param Modifiers Active modifier keys for file open-action lookup.
   --  @return Structured operation result with expanded action data.
   function Prepare_Open_Selected_Action
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result;

end Files.Operations.Opening.Testing;
