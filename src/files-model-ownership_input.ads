--  The info pane's owner and group editor: focusing it on the selected
--  item and its text buffer. Caret moves go through the parent's shared
--  text-caret operations.
package Files.Model.Ownership_Input is

   --  Open the info-pane ownership editor for the single selected item.
   --
   --  The editor buffer is prefilled with Account_Name, the resolved name of
   --  the selected item's owner or group, or with its numeric id when the name
   --  is empty. Does nothing unless exactly one non-trash item is selected whose
   --  ownership was read. Files.Operations.Metadata.Focus_Ownership_Input resolves the
   --  name and checks that the platform supports chown.
   --
   --  @param Model Model to update.
   --  @param Editing_Group True to edit the group id, False to edit the owner.
   --  @param Account_Name The owner's (or group's) name, or "" when unknown.
   procedure Focus_Ownership_Input
     (Model         : in out Window_Model;
      Editing_Group : Boolean;
      Account_Name  : String);

   --  Return the current text of the ownership editor buffer.
   --
   --  @param Model Model to inspect.
   --  @return The editor buffer contents (empty when not editing).
   function Ownership_Input_Text
     (Model : Window_Model)
      return String;

   --  Replace the ownership editor buffer with Text.
   --
   --  @param Model Model to update.
   --  @param Text New buffer contents.
   procedure Set_Ownership_Input_Text
     (Model : in out Window_Model;
      Text  : String);

   --  Return whether the ownership editor is currently editing the group id.
   --
   --  @param Model Model to inspect.
   --  @return True when editing the group, False when editing the owner.
   function Ownership_Editing_Group
     (Model : Window_Model)
      return Boolean;

end Files.Model.Ownership_Input;
