separate (Files.Operations.Undo_Recording.Try_Record_Undo)
procedure Verify_Items is
begin
   for Index in Completed.First_Index .. Completed.Last_Index loop
      declare
         Item  : Files.Undo.History.Undo_Item := Completed (Index);
         Valid : constant Boolean :=
           Payload_Is_Complete (Item)
           and then
             (if Kind = Files.Undo.History.Undo_Delete_Created
              then Creation_Snapshot_Matches
                (To_String (Item.From), To_String (Item.Identity),
                 To_String (Item.Tree_Revision), Main_Was_Verified (Index))
              else (Length (Item.Identity) > 0
                and then (Main_Was_Verified (Index)
                  or else Identity_Matches (To_String (Item.From), To_String (Item.Identity)))));
      begin
         if Valid then
            --  Only what the entry's kind uses is kept.
            if Kind = Files.Undo.History.Undo_Delete_Created then
               Item.To := Null_Unbounded_String;
            end if;
            if not Redoable
              or else Kind not in Files.Undo.History.Undo_Delete_Created | Files.Undo.History.Undo_Set_Permissions
                | Files.Undo.History.Undo_Set_Ownership
            then
               Item.Forward := Null_Unbounded_String;
            end if;
            Kept_Items.Append (Item);
         else
            Invalid_Main := True;
         end if;
      end;
   end loop;
end Verify_Items;
