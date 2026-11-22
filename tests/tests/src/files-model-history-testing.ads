--  What the suite reaches of Files.Model.History that is not part of its interface.
package Files.Model.History.Testing is

   --  Forget the entire undo and redo history, queueing the retired recovery
   --  payloads and the journal save for Take_Retired.
   --
   --  @param Model Model to update.
   procedure Clear_Undo (Model : in out Window_Model);

end Files.Model.History.Testing;
