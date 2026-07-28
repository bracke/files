with Files.Model;
with Files.Settings;

--  The undo/redo history operations of Files.Operations, extracted into a group
--  child (part of splitting the former monolith). A private child; the parent's
--  public Undo_Last/Redo_Last rename these.
private package Files.Operations.History is

   --  Reverse the most recent undoable action, then reload the directory. A
   --  partially applied reverse is pushed back onto the undo stack rather than
   --  dropped; a fully reversed redoable action moves to the redo stack.
   --
   --  @param Model Window model whose action is undone.
   --  @param Settings Settings model used for the reload.
   --  @return Success result, or a failed result when nothing/only part reverted.
   function Undo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Re-apply the most recently undone action, then reload the directory. A
   --  partially applied action stays on the redo stack for a retry.
   --
   --  @param Model Window model whose action is redone.
   --  @param Settings Settings model used for the reload.
   --  @return Success result, or a failed result when nothing/only part applied.
   function Redo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

end Files.Operations.History;
