with Files.Model;

--  Atomic helper-local snapshots retain partial history across cancellation.
package Files.History_Journal is
   --  @param Model Helper model whose history to persist.
   --  @param Required Stop the helper if this snapshot cannot be committed.
   procedure Save (Model : Files.Model.Window_Model; Required : Boolean := False);

   --  @param Model Helper model with the active action removed from its stack.
   --  @param Action Updated retry progress for the active action.
   --  @param Redo True when the action belongs on the redo stack.
   procedure Checkpoint (Model : Files.Model.Window_Model; Action : Files.Model.Undo_Entry; Redo : Boolean);

   --  @param Directory Private helper transport directory.
   --  @param Model Parent model receiving the checkpointed stacks.
   --  @return True when a complete snapshot was recovered.
   function Restore (Directory : String; Model : in out Files.Model.Window_Model) return Boolean;
end Files.History_Journal;
