separate (Files.Operations.Undo_Recording.Try_Record_Undo)
function Payload_Is_Complete (Item : Files.Undo.History.Undo_Item) return Boolean is
begin
   case Kind is
      when Files.Undo.History.Undo_Delete_Created =>
         return not Redoable
           or else (Create_Kind /= Files.Undo.History.Create_None and then Length (Item.Forward) > 0);
      when Files.Undo.History.Undo_Rename | Files.Undo.History.Undo_Move | Files.Undo.History.Undo_Restore_Trash =>
         return Length (Item.To) > 0
           and then (Kind /= Files.Undo.History.Undo_Restore_Trash or else not Redoable);
      when Files.Undo.History.Undo_Set_Permissions =>
         return Valid_Natural_Image (Item.To)
           and then (not Redoable or else Valid_Natural_Image (Item.Forward));
      when Files.Undo.History.Undo_Set_Ownership =>
         return Valid_Ownership_Image (Item.To)
           and then (not Redoable or else Valid_Ownership_Image (Item.Forward));
      when Files.Undo.History.Undo_None =>
         return False;
   end case;
end Payload_Is_Complete;
