--  What the suite reaches of Files.Operations.History that the program does
--  not do: the program never forgets a window's history while it is open.
package Files.Operations.History.Testing is

   --  Forget the entire undo and redo history, then delete the recovery
   --  payloads it retained and save the history journal.
   --
   --  @param Model Model whose history is cleared.
   procedure Clear_Undo (Model : in out Files.Model.Window_Model);

end Files.Operations.History.Testing;
