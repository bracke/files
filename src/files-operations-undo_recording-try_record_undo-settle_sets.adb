separate (Files.Operations.Undo_Recording.Try_Record_Undo)
procedure Settle_Sets is
begin
   --  A replacement reversal must remove or move every created destination
   --  before restoring its preserved originals. Dropping only an
   --  unverifiable member would make those steps refer to different sets.
   if Invalid_Restore or else (not Restores.Is_Empty and then Invalid_Main) then
      Kept_Items.Clear;
      Kept_Copies.Clear;
   elsif Kept_Items.Is_Empty and then not Kept_Copies.Is_Empty then
      --  No moved member is left to move back: the kept copies alone are
      --  undone, as the creations they are.
      Entry_Kind := Files.Undo.History.Undo_Delete_Created;
      for Copy of Kept_Copies loop
         Kept_Items.Append
           (Files.Undo.History.Undo_Item'
              (From => Copy.Path, Identity => Copy.Identity, Tree_Revision => Copy.Tree_Revision, others => <>));
      end loop;
      Kept_Copies.Clear;
   end if;
end Settle_Sets;
