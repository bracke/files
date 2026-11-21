separate (Files.Operations.Undo_Recording.Try_Record_Undo)
procedure Capture_Items is
begin
   for Index in Completed.First_Index .. Completed.Last_Index loop
      declare
         Item : Files.Undo.History.Undo_Item renames Completed (Index);
      begin
         if Items (Index).Provenance = Files.Undo.History.Captured then
            Item.Identity := To_Unbounded_String (Files.File_Identities.Token (To_String (Item.From)));
            Item.Tree_Revision :=
              (if Kind = Files.Undo.History.Undo_Delete_Created
               then To_Unbounded_String (Tree_Revision_Or_Empty (To_String (Item.From)))
               else Null_Unbounded_String);
         end if;
         if Kind = Files.Undo.History.Undo_Restore_Trash and then Length (Item.To) = 0 then
            Item.To := To_Unbounded_String (Files.File_System.Trash.Trash_Original_Path (To_String (Item.From)));
         end if;
      end;
   end loop;
end Capture_Items;
