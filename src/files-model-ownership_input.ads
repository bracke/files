--  The ownership input state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Ownership_Input is

   --  Open the info-pane ownership editor for the single selected item.
   --
   --  The editor buffer is prefilled with the selected item's current numeric
   --  owner or group id. Does nothing unless exactly one non-trash item is
   --  selected whose ownership was read on a platform that supports chown.
   --
   --  @param Model Model to update.
   --  @param Editing_Group True to edit the group id, False to edit the owner.
   procedure Focus_Ownership_Input
     (Model         : in out Window_Model;
      Editing_Group : Boolean);

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
