separate (Files.Operations.Undo_Recording.Try_Record_Undo)
procedure Verify_Kept_Copies is
begin
   --  A kept copy is deleted by Undo only while it is still the copy the
   --  failed move published. One that cannot be verified is left out -- but
   --  not when an original a replace preserved goes back to its path: that
   --  restore would meet the unverified copy, so nothing is recorded.
   for Copy of Kept loop
      if Kind = Files.Undo.History.Undo_Move
        and then Length (Copy.Identity) > 0
        and then Creation_Snapshot_Matches
          (To_String (Copy.Path), To_String (Copy.Identity), To_String (Copy.Tree_Revision), False)
      then
         Kept_Copies.Append (Copy);
      elsif (for some Original of Restores => Original.Target = Copy.Path) then
         Invalid_Restore := True;
      end if;
   end loop;
end Verify_Kept_Copies;
