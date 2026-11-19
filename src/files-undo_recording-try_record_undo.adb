separate (Files.Undo_Recording)
function Try_Record_Undo
  (Model       : in out Files.Model.Window_Model;
   Kind        : Files.Undo_History.Undo_Action_Kind;
   Items       : Files.Undo_History.Recorded_Item_Vectors.Vector;
   Create_Kind : Files.Undo_History.Undo_Create_Kind := Files.Undo_History.Create_None;
   Redoable    : Boolean := True;
   Replaced    : Files.Undo_History.Recorded_Original_Vectors.Vector :=
     Files.Undo_History.Recorded_Original_Vectors.Empty_Vector;
   Kept        : Files.Undo_History.Kept_Copy_Vectors.Vector := Files.Undo_History.Kept_Copy_Vectors.Empty_Vector)
   return Boolean
is
   function Identity_Matches (Path, Expected : String) return Boolean
     renames Files.File_System.Entry_Identity_Matches;
   function Creation_Snapshot_Matches
     (Path, Identity, Tree_Revision : String;
      Retain_Verified : Boolean) return Boolean
     renames Files.File_System.Creation_Matches;
   function Valid_Natural_Image (Value : Unbounded_String) return Boolean is
     (Files.Undo_Payloads.Is_Mode_Text (To_String (Value)));
   function Valid_Ownership_Image (Value : Unbounded_String) return Boolean is
     (Files.Undo_Payloads.Is_Ownership_Text (To_String (Value)));

   use type Files.Undo_History.Item_Provenance;

   --  The items and originals as given, completed with what was not.
   Completed : Files.Undo_History.Undo_Item_Vectors.Vector;
   Restores : Files.Undo_History.Replaced_Original_Vectors.Vector;
   --  What the entry keeps: each verified item and kept copy.
   Kept_Items  : Files.Undo_History.Undo_Item_Vectors.Vector;
   Kept_Copies : Files.Undo_History.Kept_Copy_Vectors.Vector;
   --  An entry that deletes kept copies first is undo-only: redoing the move
   --  would collide with the sources the failed move left in place.
   Entry_Redoable : constant Boolean := Redoable and then Kept.Is_Empty;
   Entry_Kind : Files.Undo_History.Undo_Action_Kind := Kind;
   Invalid_Main : Boolean := False;
   Invalid_Restore : Boolean := False;
   Recorded : Boolean;

   function Tree_Revision_Or_Empty (Path : String) return String is
   begin
      return Files.File_System.Tree_Revision (Path);
   exception
      --  A creation may already be published when its snapshot is captured.
      --  Keep the operation successful, but omit unsafe Undo for this entry.
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Undo_Recording");
         return "";
   end Tree_Revision_Or_Empty;

   --  An item or original verified at publication is trusted without a
   --  fresh check.
   function Main_Was_Verified (Index : Positive) return Boolean is
     (Items (Index).Provenance = Files.Undo_History.Verified);

   function Restore_Was_Verified (Index : Positive) return Boolean is
     (Replaced (Index).Provenance = Files.Undo_History.Verified);

   function Payload_Is_Complete (Item : Files.Undo_History.Undo_Item) return Boolean is
   begin
      case Kind is
         when Files.Undo_History.Undo_Delete_Created =>
            return not Redoable
              or else (Create_Kind /= Files.Undo_History.Create_None and then Length (Item.Forward) > 0);
         when Files.Undo_History.Undo_Rename | Files.Undo_History.Undo_Move | Files.Undo_History.Undo_Restore_Trash =>
            return Length (Item.To) > 0
              and then (Kind /= Files.Undo_History.Undo_Restore_Trash or else not Redoable);
         when Files.Undo_History.Undo_Set_Permissions =>
            return Valid_Natural_Image (Item.To)
              and then (not Redoable or else Valid_Natural_Image (Item.Forward));
         when Files.Undo_History.Undo_Set_Ownership =>
            return Valid_Ownership_Image (Item.To)
              and then (not Redoable or else Valid_Ownership_Image (Item.Forward));
         when Files.Undo_History.Undo_None =>
            return False;
      end case;
   end Payload_Is_Complete;
begin
   --  The model advances its revision and notes completed renames and moves;
   --  everything that reads the filesystem happens here, before the model
   --  commits the entry.
   for Given of Items loop
      Completed.Append (Given.Item);
   end loop;
   for Given of Replaced loop
      Restores.Append (Given.Original);
   end loop;
   Files.Model.History.Begin_Undo_Record (Model, Kind, Completed);
   if Kind = Files.Undo_History.Undo_None or else (Items.Is_Empty and then Kept.Is_Empty) then
      return False;
   end if;
   if Undo_Record_Attempted /= null then
      Undo_Record_Attempted.all;
   end if;

   for Index in Completed.First_Index .. Completed.Last_Index loop
      declare
         Item : Files.Undo_History.Undo_Item renames Completed (Index);
      begin
         if Items (Index).Provenance = Files.Undo_History.Captured then
            Item.Identity := To_Unbounded_String (Files.File_Identities.Token (To_String (Item.From)));
            Item.Tree_Revision :=
              (if Kind = Files.Undo_History.Undo_Delete_Created
               then To_Unbounded_String (Tree_Revision_Or_Empty (To_String (Item.From)))
               else Null_Unbounded_String);
         end if;
         if Kind = Files.Undo_History.Undo_Restore_Trash and then Length (Item.To) = 0 then
            Item.To := To_Unbounded_String (Files.File_System.Trash.Trash_Original_Path (To_String (Item.From)));
         end if;
      end;
   end loop;

   for Index in Restores.First_Index .. Restores.Last_Index loop
      if Replaced (Index).Provenance = Files.Undo_History.Captured then
         declare
            Original : Files.Undo_History.Replaced_Original renames Restores (Index);
         begin
            Original.Target :=
              To_Unbounded_String (Files.File_System.Trash.Trash_Original_Path (To_String (Original.Trash)));
            Original.Identity := To_Unbounded_String (Files.File_Identities.Token (To_String (Original.Trash)));
         end;
      end if;
   end loop;
   if not Restores.Is_Empty and then Redoable then
      Invalid_Restore := True;
   end if;

   for Index in Restores.First_Index .. Restores.Last_Index loop
      if Length (Restores (Index).Target) = 0
        or else Length (Restores (Index).Identity) = 0
        or else (not Restore_Was_Verified (Index)
          and then not Identity_Matches
            (To_String (Restores (Index).Trash), To_String (Restores (Index).Identity)))
      then
         Invalid_Restore := True;
      end if;
   end loop;

   for Index in Completed.First_Index .. Completed.Last_Index loop
      declare
         Item  : Files.Undo_History.Undo_Item := Completed (Index);
         Valid : constant Boolean :=
           Payload_Is_Complete (Item)
           and then
             (if Kind = Files.Undo_History.Undo_Delete_Created
              then Creation_Snapshot_Matches
                (To_String (Item.From), To_String (Item.Identity),
                 To_String (Item.Tree_Revision), Main_Was_Verified (Index))
              else (Length (Item.Identity) > 0
                and then (Main_Was_Verified (Index)
                  or else Identity_Matches (To_String (Item.From), To_String (Item.Identity)))));
      begin
         if Valid then
            --  Only what the entry's kind uses is kept.
            if Kind = Files.Undo_History.Undo_Delete_Created then
               Item.To := Null_Unbounded_String;
            end if;
            if not Redoable
              or else Kind not in Files.Undo_History.Undo_Delete_Created | Files.Undo_History.Undo_Set_Permissions
                | Files.Undo_History.Undo_Set_Ownership
            then
               Item.Forward := Null_Unbounded_String;
            end if;
            Kept_Items.Append (Item);
         else
            Invalid_Main := True;
         end if;
      end;
   end loop;

   --  A kept copy is deleted by Undo only while it is still the copy the
   --  failed move published. One that cannot be verified is left out -- but
   --  not when an original a replace preserved goes back to its path: that
   --  restore would meet the unverified copy, so nothing is recorded.
   for Copy of Kept loop
      if Kind = Files.Undo_History.Undo_Move
        and then Length (Copy.Identity) > 0
        and then Creation_Snapshot_Matches
          (To_String (Copy.Path), To_String (Copy.Identity), To_String (Copy.Tree_Revision), False)
      then
         Kept_Copies.Append (Copy);
      elsif (for some Original of Restores => Original.Target = Copy.Path) then
         Invalid_Restore := True;
      end if;
   end loop;

   --  A replacement reversal must remove or move every created destination
   --  before restoring its preserved originals. Dropping only an
   --  unverifiable member would make those steps refer to different sets.
   if Invalid_Restore or else (not Restores.Is_Empty and then Invalid_Main) then
      Kept_Items.Clear;
      Kept_Copies.Clear;
   elsif Kept_Items.Is_Empty and then not Kept_Copies.Is_Empty then
      --  No moved member is left to move back: the kept copies alone are
      --  undone, as the creations they are.
      Entry_Kind := Files.Undo_History.Undo_Delete_Created;
      for Copy of Kept_Copies loop
         Kept_Items.Append
           (Files.Undo_History.Undo_Item'
              (From => Copy.Path, Identity => Copy.Identity, Tree_Revision => Copy.Tree_Revision, others => <>));
      end loop;
      Kept_Copies.Clear;
   end if;

   --  The model retires the redo stack (and, past its depth cap, the oldest
   --  undo entries) before pushing; their payloads are deleted and the
   --  journal saved only once the entries have left both stacks.
   Recorded := Files.Model.History.Commit_Undo_Record
     (Model,
      Files.Undo_History.Undo_Entry'
        (Kind        => Entry_Kind,
         Items       => Kept_Items,
         Create_Kind => Create_Kind,
         Redoable    => Entry_Redoable,
         Replaced    => Restores,
         Kept        => Kept_Copies,
         others      => <>));
   Settle_History (Model);
   return Recorded;
end Try_Record_Undo;
