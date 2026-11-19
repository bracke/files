separate (Files.Operations)
--  Apply the reverse (undo) direction of Action, one journaled history
--  entry. Returns True on full success.
function Apply_Reverse
  (Action : in out Files.Model.Undo_Entry; Model : in out Files.Model.Window_Model)
   return Boolean
is
   Succeeded : Boolean := True;
   Reversed  : Path_Sets.Set := To_Set (Action.Reverse_Completed);

   --  Whether the item restored to Original.Target is the trashed one
   --  itself (a rename keeps its identity), so a retry recognises it there.
   function Restored_In_Place (Original : Files.Model.Replaced_Original) return Boolean is
     (Length (Original.Target) > 0
      and then Length (Original.Identity) > 0
      and then Files.File_Identities.Token (To_String (Original.Target)) = To_String (Original.Identity));

   --  A trashed main item as the original it restores.
   function Trashed (Item : Files.Model.Undo_Item) return Files.Model.Replaced_Original is
     ((Trash => Item.From, Identity => Item.Identity, Target => Item.To));
   Restored  : Path_Sets.Set := To_Set (Action.Restores_Completed);

   --  Remove Path, an entry this action created, if it is still that entry:
   --  Identity matches, and Delete_Created_Entry checks Tree_Revision as it
   --  removes it. A path gone for sure is already removed; one the host will
   --  not answer for, or another entry under the name, is not, and a retry
   --  repeats the step. A removed path is marked reversed and the journal
   --  checkpointed (Force: written now rather than when next due), so a
   --  retry never deletes what a restore has since put there.
   function Remove_Created
     (Path : Files.Types.UString; Identity, Tree_Revision : String; Force : Boolean) return Boolean
   is
      Target : constant String := To_String (Path);
   begin
      if Reversed.Contains (Target) then
         return True;
      elsif not Files.Fs_Primitives.Entry_Is_Absent (Target)
        and then (Identity = ""
          or else Files.File_Identities.Token (Target) /= Identity
          or else not Files.File_System.Delete_Created_Entry (Target, Identity, Tree_Revision).Success)
      then
         return False;
      end if;
      Action.Reverse_Completed.Append (Path);
      Reversed.Include (Target);
      Files.History_Journal.Checkpoint (Model, Action, Files.Model.Undo_Side, Force => Force);
      return True;
   end Remove_Created;
begin
   --  Copies a failed move kept beside their sources leave first: before
   --  anything moves back, and before an original a replace preserved is
   --  restored to the path one of them holds. Each step is marked, so a
   --  retry never deletes what a restore has since put there.
   for Copy of Action.Kept loop
      if Files.Job_Context.Cancelled then
         return False;
      end if;
      if not Remove_Created (Copy.Path, To_String (Copy.Identity), To_String (Copy.Tree_Revision), Force => True) then
         Succeeded := False;
      end if;
   end loop;
   --  An original goes back only to a path no kept copy still holds.
   if not Succeeded then
      return False;
   end if;

   case Action.Kind is
      when Files.Model.Undo_Rename | Files.Model.Undo_Move =>
         Succeeded := Move_Back (Action, Model, Files.Model.Undo_Side);

      when Files.Model.Undo_Restore_Trash =>
         for Item of Action.Items loop
            if Files.Job_Context.Cancelled then
               return False;
            end if;
            if Reversed.Contains (To_String (Item.From)) then
               null;
            elsif not Restore_Recorded_Trash (Trashed (Item)) then
               Succeeded := False;
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
               Files.History_Journal.Checkpoint
                 (Model, Action, Files.Model.Undo_Side, Force => not Restored_In_Place (Trashed (Item)));
            end if;
         end loop;

      when Files.Model.Undo_Delete_Created =>
         --  Undo a created path by removing it again. A path gone for sure
         --  is already undone; one the host will not answer for is not.
         for Index in Action.Items.First_Index .. Action.Items.Last_Index loop
            if Files.Job_Context.Cancelled then
               return False;
            end if;
            declare
               Item : constant Files.Model.Undo_Item := Action.Items (Index);
            begin
               --  A retry treats a path already gone as removed, so its
               --  checkpoint can wait.
               if not Remove_Created
                 (Item.From, To_String (Item.Identity), To_String (Item.Tree_Revision), Force => False)
               then
                  Succeeded := False;
               end if;
            end;
         end loop;

      when Files.Model.Undo_Set_Permissions | Files.Model.Undo_Set_Ownership =>
         --  Put back the mode or owner the change replaced (To).
         case Replay_Metadata (Action, Before_Change) is
            when Stopped     => return False;
            when Item_Failed => Succeeded := False;
            when Replayed    => null;
         end case;

      when Files.Model.Undo_None =>
         Succeeded := False;
   end case;

   --  Paste-replace: after the main reverse has vacated each destination
   --  (deleted the pasted copy / moved the source back), restore the original
   --  that the Replace moved to the trash, so undo returns the pre-paste state.
   for Original of Action.Replaced loop
      if Files.Job_Context.Cancelled then
         return False;
      end if;
      if Restored.Contains (To_String (Original.Trash)) then
         null;
      elsif not Restore_Recorded_Trash (Original) then
         Succeeded := False;
      else
         --  Its labels, favorite and recent entry come back with it.
         Files.Model.Note_Path_Move (Model, To_String (Original.Trash), To_String (Original.Target));
         Action.Restores_Completed.Append (Original.Trash);
         Restored.Include (To_String (Original.Trash));
         Files.History_Journal.Checkpoint
           (Model, Action, Files.Model.Undo_Side, Force => not Restored_In_Place (Original));
      end if;
   end loop;

   return Succeeded;
end Apply_Reverse;
