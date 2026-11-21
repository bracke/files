separate (Files.Operations)
--  Apply the reverse (undo) direction of Action, one journaled history
--  entry. Returns True on full success.
function Apply_Reverse
  (Action : in out Files.Undo.History.Undo_Entry; Model : in out Files.Model.Window_Model)
   return Boolean
is
   Succeeded : Boolean := True;
   Reversed  : Path_Sets.Set := To_Set (Action.Reverse_Completed);

   --  Whether the item restored to Original.Target is the trashed one
   --  itself (a rename keeps its identity), so a retry recognises it there.
   function Restored_In_Place (Original : Files.Undo.History.Replaced_Original) return Boolean is
     (Length (Original.Target) > 0
      and then Length (Original.Identity) > 0
      and then Files.File_Identities.Token (To_String (Original.Target)) = To_String (Original.Identity));

   --  A trashed main item as the original it restores.
   function Trashed (Item : Files.Undo.History.Undo_Item) return Files.Undo.History.Replaced_Original is
     ((Trash => Item.From, Identity => Item.Identity, Target => Item.To));
   Restored  : Path_Sets.Set := To_Set (Action.Restores_Completed);

   --  Remove Path, an entry this action created, if it is still that entry:
   --  Identity matches, and Delete_Created_Entry checks Tree_Revision as it
   --  removes it. A path gone for sure is already removed; one the host will
   --  not answer for, or another entry under the name, is not, and a retry
   --  repeats the step. A removed path is marked reversed and the journal
   --  checkpointed as Timing says (Write_Now: written now rather than when
   --  next due), so a
   --  retry never deletes what a restore has since put there.
   function Remove_Created
     (Path : Files.Types.UString; Identity, Tree_Revision : String;
      Timing : Files.Undo.Journal.Checkpoint_Timing) return Boolean
   is
      Target : constant String := To_String (Path);
   begin
      if Reversed.Contains (Target) then
         return True;
      elsif not Files.IO.Fs_Primitives.Entry_Is_Absent (Target)
        and then (Identity = ""
          or else Files.File_Identities.Token (Target) /= Identity
          or else not Files.File_System.Delete_Created_Entry (Target, Identity, Tree_Revision).Success)
      then
         return False;
      end if;
      Action.Reverse_Completed.Append (Path);
      Reversed.Include (Target);
      Files.Undo.Journal.Checkpoint
        (Files.Model.History.State (Model), Action, Files.Undo.History.Undo_Side, Timing => Timing);
      return True;
   end Remove_Created;

   --  Copies a failed move kept beside their sources leave first: before
   --  anything moves back, and before an original a replace preserved is
   --  restored to the path one of them holds. Each step is marked, so a
   --  retry never deletes what a restore has since put there.
   function Remove_Kept_Copies return Replay_Outcome is
      Outcome : Replay_Outcome := Replayed;
   begin
      for Copy of Action.Kept loop
         if Files.Jobs.Context.Cancelled then
            return Stopped;
         end if;
         if not Remove_Created (Copy.Path, To_String (Copy.Identity), To_String (Copy.Tree_Revision),
                                Timing => Files.Undo.Journal.Write_Now)
         then
            Outcome := Item_Failed;
         end if;
      end loop;
      return Outcome;
   end Remove_Kept_Copies;

   --  Put each item a trashing moved back from the trash, skipping those a
   --  retry finds already reversed.
   function Restore_Trashed_Items return Replay_Outcome is
      Outcome : Replay_Outcome := Replayed;
   begin
      for Item of Action.Items loop
         if Files.Jobs.Context.Cancelled then
            return Stopped;
         end if;
         if Reversed.Contains (To_String (Item.From)) then
            null;
         elsif not Restore_Recorded_Trash (Trashed (Item)) then
            Outcome := Item_Failed;
         else
            --  Its labels come back out of the trash with it.
            if Length (Item.To) > 0 then
               Files.Model.Note_Path_Move (Model, To_String (Item.From), To_String (Item.To));
            end if;
            Action.Reverse_Completed.Append (Item.From);
            Reversed.Include (To_String (Item.From));
            --  A retry finds a finished restore by its identity at the
            --  original path (Restore_Recorded_Trash) -- unless it was a
            --  copy across devices, which has a new one: written now.
            Files.Undo.Journal.Checkpoint
              (Files.Model.History.State (Model), Action, Files.Undo.History.Undo_Side,
               Timing =>
                 (if Restored_In_Place (Trashed (Item)) then Files.Undo.Journal.Within_Second
                  else Files.Undo.Journal.Write_Now));
         end if;
      end loop;
      return Outcome;
   end Restore_Trashed_Items;

   --  Undo a created path by removing it again. A path gone for sure is
   --  already undone; one the host will not answer for is not.
   function Remove_Created_Items return Replay_Outcome is
      Outcome : Replay_Outcome := Replayed;
   begin
      for Index in Action.Items.First_Index .. Action.Items.Last_Index loop
         if Files.Jobs.Context.Cancelled then
            return Stopped;
         end if;
         declare
            Item : constant Files.Undo.History.Undo_Item := Action.Items (Index);
         begin
            --  A retry treats a path already gone as removed, so its
            --  checkpoint can wait.
            if not Remove_Created
              (Item.From, To_String (Item.Identity), To_String (Item.Tree_Revision),
               Timing => Files.Undo.Journal.Within_Second)
            then
               Outcome := Item_Failed;
            end if;
         end;
      end loop;
      return Outcome;
   end Remove_Created_Items;

   --  Paste-replace: after the main reverse has vacated each destination
   --  (deleted the pasted copy / moved the source back), restore the original
   --  that the Replace moved to the trash, so undo returns the pre-paste state.
   function Restore_Replaced_Originals return Replay_Outcome is
      Outcome : Replay_Outcome := Replayed;
   begin
      for Original of Action.Replaced loop
         if Files.Jobs.Context.Cancelled then
            return Stopped;
         end if;
         if Restored.Contains (To_String (Original.Trash)) then
            null;
         elsif not Restore_Recorded_Trash (Original) then
            Outcome := Item_Failed;
         else
            --  Its labels, favorite and recent entry come back with it.
            Files.Model.Note_Path_Move (Model, To_String (Original.Trash), To_String (Original.Target));
            Action.Restores_Completed.Append (Original.Trash);
            Restored.Include (To_String (Original.Trash));
            Files.Undo.Journal.Checkpoint
              (Files.Model.History.State (Model), Action, Files.Undo.History.Undo_Side,
               Timing =>
                 (if Restored_In_Place (Original) then Files.Undo.Journal.Within_Second
                  else Files.Undo.Journal.Write_Now));
         end if;
      end loop;
      return Outcome;
   end Restore_Replaced_Originals;

   --  The reverse of the action's own kind of change.
   function Reverse_Main return Replay_Outcome is
   begin
      case Action.Kind is
         when Files.Undo.History.Undo_Rename | Files.Undo.History.Undo_Move =>
            return (if Move_Back (Action, Model, Files.Undo.History.Undo_Side) then Replayed else Item_Failed);
         when Files.Undo.History.Undo_Restore_Trash =>
            return Restore_Trashed_Items;
         when Files.Undo.History.Undo_Delete_Created =>
            return Remove_Created_Items;
         when Files.Undo.History.Undo_Set_Permissions | Files.Undo.History.Undo_Set_Ownership =>
            --  Put back the mode or owner the change replaced (To).
            return Replay_Metadata (Action, Before_Change);
         when Files.Undo.History.Undo_None =>
            return Item_Failed;
      end case;
   end Reverse_Main;
begin
   --  An original goes back only to a path no kept copy still holds.
   if Remove_Kept_Copies /= Replayed then
      return False;
   end if;
   case Reverse_Main is
      when Stopped     => return False;
      when Item_Failed => Succeeded := False;
      when Replayed    => null;
   end case;
   case Restore_Replaced_Originals is
      when Stopped     => return False;
      when Item_Failed => Succeeded := False;
      when Replayed    => null;
   end case;
   return Succeeded;
end Apply_Reverse;
