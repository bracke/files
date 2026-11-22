with Files.Model.History.Testing;
with Files.Operations.Undo_Recording;

package body Files.Operations.History.Testing is

   procedure Clear_Undo (Model : in out Files.Model.Window_Model) is
   begin
      Files.Model.History.Testing.Clear_Undo (Model);
      Files.Operations.Undo_Recording.Settle_History (Model);
   end Clear_Undo;

end Files.Operations.History.Testing;
