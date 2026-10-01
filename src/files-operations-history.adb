with Files.Copy_Context;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Files.File_System;
with Files.Types;
with Files.Job_Context;
with Files.History_Journal;
with Files.Operation_Jobs;
with Files.File_Identities;

with Files.Operations.Support;

separate (Files.Operations)
package body History is
   use type Files.Model.Undo_Action_Kind;
   use type Files.Model.Undo_Create_Kind;

   function Hard_Link_Snapshot (Source : String) return String is
   begin
      return Files.File_System.Tree_Revision (Source);
   exception
      when others =>
         return "";
   end Hard_Link_Snapshot;

   procedure Remove_Completion
     (Action : in out Files.Model.Undo_Entry;
      Path : Files.Types.UString;
      Forward : Boolean)
   is
   begin
      if Forward then
         for Index in reverse
           Action.Forward_Completed.First_Index .. Action.Forward_Completed.Last_Index
         loop
            if Action.Forward_Completed (Index) = Path then
               Action.Forward_Completed.Delete (Index);
            end if;
         end loop;
      else
         for Index in reverse
           Action.Reverse_Completed.First_Index .. Action.Reverse_Completed.Last_Index
         loop
            if Action.Reverse_Completed (Index) = Path then
               Action.Reverse_Completed.Delete (Index);
            end if;
         end loop;
      end if;
   end Remove_Completion;

   function Move_Back
     (Action : in out Files.Model.Undo_Entry;
      Model : Files.Model.Window_Model;
      Forward : Boolean) return Boolean
   is
      Sources : constant Files.Types.String_Vectors.Vector := (if Forward then Action.To else Action.From);
      Targets : constant Files.Types.String_Vectors.Vector := (if Forward then Action.From else Action.To);
      Succeeded : Boolean := True;
      procedure Completed (Path : Files.Types.UString) is
      begin
         if Forward then
            Action.Forward_Completed.Append (Path);
         else
            Action.Reverse_Completed.Append (Path);
         end if;
         Files.History_Journal.Checkpoint (Model, Action, Forward);
      end Completed;
   begin
      for Index in Sources.First_Index .. Sources.Last_Index loop
         if Files.Job_Context.Cancelled then
            return False;
         end if;
         declare
            Source : constant String := To_String (Sources.Element (Index));
            Target : constant String := To_String (Targets.Element (Index));
            Identity : constant String :=
              (if Index <= Action.Created_Identities.Last_Index
               then To_String (Action.Created_Identities (Index)) else "");
            Marked : constant Boolean :=
              (if Forward
               then Action.Forward_Completed.Contains (Sources (Index))
               else Action.Reverse_Completed.Contains (Sources (Index)));
            Matches : constant Boolean :=
              Identity /= "" and then Files.File_Identities.Token (Target) = Identity;
         begin
            if Marked and then Matches then
               null;
            else
               if Marked then
                  Remove_Completion (Action, Sources (Index), Forward);
                  Files.History_Journal.Checkpoint (Model, Action, Forward);
               end if;
               if Identity = "" then
                  Succeeded := False;
               elsif Matches then
                  Completed (Sources (Index));
               elsif Exists_Safely (Source) then
                  if Files.File_System.Rename_Item (Source, Target, Identity).Success then
                     --  A cross-device copy gives the moved entry a new identity.
                     Action.Created_Identities.Replace_Element
                       (Index, To_Unbounded_String (Files.File_Identities.Token (Target)));
                     Completed (Sources (Index));
                  else
                     Succeeded := False;
                  end if;
               else
                  Succeeded := False;
               end if;
            end if;
         end;
      end loop;
      return Succeeded;
   end Move_Back;

   function Change_Recorded_Metadata
     (Action : Files.Model.Undo_Entry; Index : Positive; Ownership : Boolean;
      Value : Natural; Group : Natural := 0) return Boolean
   is
      Previous, Previous_Group : Natural;
      Identity : Files.Types.UString;
   begin
      if Index > Action.Created_Identities.Last_Index or else Length (Action.Created_Identities (Index)) = 0 then
         return False;
      end if;
      return Files.File_System.Change_Metadata
        (To_String (Action.From (Index)), To_String (Action.Created_Identities (Index)),
         Ownership, Value, Group, Previous, Previous_Group, Identity).Success;
   end Change_Recorded_Metadata;

   function Restore_Recorded_Trash
     (Path : Files.Types.UString; Identities, Targets : Files.Types.String_Vectors.Vector;
      Index : Positive) return Boolean is
   begin
      if Index > Identities.Last_Index or else Length (Identities (Index)) = 0
        or else Index > Targets.Last_Index or else Length (Targets (Index)) = 0
      then
         return False;
      end if;
      return Files.File_System.Restore_From_Trash
        (To_String (Path), To_String (Identities (Index)), To_String (Targets (Index))).Success;
   end Restore_Recorded_Trash;

   --  Apply the reverse (undo) direction of Action. Returns True on full
   --  success. Mirrors the pre-existing single-level undo behaviour.
   function Apply_Reverse
     (Action : in out Files.Model.Undo_Entry; Model : Files.Model.Window_Model)
      return Boolean
   is
      Succeeded : Boolean := True;
   begin
      case Action.Kind is
         when Files.Model.Undo_Rename | Files.Model.Undo_Move =>
            Succeeded := Move_Back (Action, Model, False);

         when Files.Model.Undo_Restore_Trash =>
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               if Files.Job_Context.Cancelled then
                  return False;
               end if;
               if Action.Reverse_Completed.Contains (Action.From.Element (Index)) then
                  null;
               elsif not Restore_Recorded_Trash (Action.From (Index), Action.Created_Identities, Action.To, Index)
               then
                  Succeeded := False;
               else
                  Action.Reverse_Completed.Append (Action.From.Element (Index));
                  Files.History_Journal.Checkpoint (Model, Action, False);
               end if;
            end loop;

         when Files.Model.Undo_Delete_Created =>
            --  Undo a created path by removing it again. Missing paths are
            --  treated as already undone.
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               if Files.Job_Context.Cancelled then
                  return False;
               end if;
               declare
                  Target : constant String := To_String (Action.From.Element (Index));
                  Expected_Identity, Expected_Tree_Revision : Files.Types.UString;
               begin
                  if Index <= Action.Created_Identities.Last_Index then
                     Expected_Identity := Action.Created_Identities (Index);
                  end if;
                  if Index <= Action.Created_Tree_Revisions.Last_Index then
                     Expected_Tree_Revision := Action.Created_Tree_Revisions (Index);
                  end if;
                  if Action.Reverse_Completed.Contains (Action.From.Element (Index)) then
                     null;
                  elsif Exists_Safely (Target)
                    and then (Length (Expected_Identity) = 0
                              or else Files.File_Identities.Token (Target) /= To_String (Expected_Identity))
                  then
                     Succeeded := False;
                  elsif Exists_Safely (Target)
                    and then not Files.File_System.Delete_Created_Entry
                      (Target, To_String (Expected_Identity), To_String (Expected_Tree_Revision)).Success
                  then
                     Succeeded := False;
                  else
                     Action.Reverse_Completed.Append (Action.From.Element (Index));
                     Files.History_Journal.Checkpoint (Model, Action, False);
                  end if;
               end;
            end loop;

         when Files.Model.Undo_Set_Permissions =>
            --  Restore the previous mode recorded before the chmod. From holds
            --  the path and To holds the decimal image of the old mode bits.
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               if Files.Job_Context.Cancelled then
                  return False;
               end if;
               if Index > Action.To.Last_Index then
                  --  Malformed entry: To shorter than From. Fail this item
                  --  rather than index out of range (mirrors the forward guard).
                  Succeeded := False;
               else
                  declare

                     Old_Text : constant String :=
                       Ada.Strings.Fixed.Trim (To_String (Action.To.Element (Index)), Ada.Strings.Both);
                     Old_Mode : Natural := 0;
                  begin
                     begin
                        Old_Mode := Natural'Value (Old_Text);
                     exception
                        when others =>
                           Succeeded := False;
                     end;

                     if Old_Mode > 0 or else Old_Text = "0" then
                        if not Change_Recorded_Metadata (Action, Index, False, Old_Mode) then
                           Succeeded := False;
                        end if;
                     end if;
                  end;
               end if;
            end loop;

         when Files.Model.Undo_Set_Ownership =>
            --  Restore the previous owner/group recorded before the chown.
            --  From holds the path and To holds "uid gid" decimal images.
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               if Files.Job_Context.Cancelled then
                  return False;
               end if;
               if Index > Action.To.Last_Index then
                  Succeeded := False;
               else
                  declare

                     Old_Text : constant String :=
                       Ada.Strings.Fixed.Trim (To_String (Action.To.Element (Index)), Ada.Strings.Both);
                     Space    : constant Natural := Ada.Strings.Fixed.Index (Old_Text, " ");
                     Old_Uid  : Natural := 0;
                     Old_Gid  : Natural := 0;
                  begin
                     if Space > 0 then
                        begin
                           Old_Uid := Natural'Value (Old_Text (Old_Text'First .. Space - 1));
                           Old_Gid := Natural'Value (Old_Text (Space + 1 .. Old_Text'Last));
                           if not Change_Recorded_Metadata (Action, Index, True, Old_Uid, Old_Gid) then
                              Succeeded := False;
                           end if;
                        exception
                           when others =>
                              Succeeded := False;
                        end;
                     else
                        Succeeded := False;
                     end if;
                  end;
               end if;
            end loop;

         when Files.Model.Undo_None =>
            Succeeded := False;
      end case;

      --  Paste-replace: after the main reverse has vacated each destination
      --  (deleted the pasted copy / moved the source back), restore the original
      --  that the Replace moved to the trash, so undo returns the pre-paste state.
      for Index in Action.Restore_Trash.First_Index .. Action.Restore_Trash.Last_Index loop
         if Files.Job_Context.Cancelled then
            return False;
         end if;
         if Action.Restores_Completed.Contains (Action.Restore_Trash.Element (Index)) then
            null;
         elsif not Restore_Recorded_Trash
                    (Action.Restore_Trash (Index), Action.Restore_Identities, Action.Restore_Targets, Index)
         then
            Succeeded := False;
         else
            Action.Restores_Completed.Append (Action.Restore_Trash.Element (Index));
            Files.History_Journal.Checkpoint (Model, Action, False);
         end if;
      end loop;

      return Succeeded;
   end Apply_Reverse;

   function Completed_Creation_Matches
     (Action : Files.Model.Undo_Entry; Index : Positive; Path : String)
      return Boolean
   is
      Identity : constant String :=
        (if Index <= Action.Created_Identities.Last_Index
         then To_String (Action.Created_Identities (Index)) else "");
      Expected_Tree_Revision : constant String :=
        (if Index <= Action.Created_Tree_Revisions.Last_Index
         then To_String (Action.Created_Tree_Revisions (Index)) else "");
      Is_Link : Boolean;
   begin
      if Identity = "" or else Files.File_Identities.Token (Path) /= Identity then
         return False;
      end if;
      Is_Link := Hostkit.Fs.Is_Link (Path);
      return
        (if Is_Link then Expected_Tree_Revision = ""
         else Expected_Tree_Revision /= ""
           and then Files.File_System.Tree_Revision (Path) = Expected_Tree_Revision);
   exception
      when others =>
         return False;
   end Completed_Creation_Matches;

   --  Apply the forward (redo) direction of Action. Returns True on full
   --  success. Undo_Restore_Trash is undo-only and never reaches here.
   function Apply_Forward
     (Action : in out Files.Model.Undo_Entry; Model : Files.Model.Window_Model)
      return Boolean
   is
      Succeeded : Boolean := True;
      Copy_Batch : Files.Copy_Context.Session;
   begin
      if Action.Kind = Files.Model.Undo_Delete_Created and then Action.Create_Kind = Files.Model.Create_Copy
        and then Natural (Action.From.Length) > 1
      then
         Copy_Batch := Files.Copy_Context.Create;
         Files.Copy_Context.Save (Copy_Batch, Action.Copy_Records);
      end if;
      case Action.Kind is
         when Files.Model.Undo_Rename | Files.Model.Undo_Move =>
            --  Re-run the original transition: from the reverted (To) location
            --  back to the post-operation (From) location.
            Succeeded := Move_Back (Action, Model, True);

         when Files.Model.Undo_Delete_Created =>
            --  Re-create each destination from its recorded source, retaining
            --  successful publications across retries of a partial Redo.
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               if Files.Job_Context.Cancelled then
                  return False;
               end if;
               declare
                  Dest   : constant String := To_String (Action.From.Element (Index));
                  Source : constant String :=
                    (if Index <= Action.Forward.Last_Index
                     then To_String (Action.Forward.Element (Index))
                     else "");
                  Marked : constant Boolean :=
                    Action.Forward_Completed.Contains (Action.From.Element (Index));
                  Matches : constant Boolean :=
                    Completed_Creation_Matches (Action, Index, Dest);
               begin
                  if Matches then
                     --  A helper may have published the entry before its
                     --  completion marker reached the history journal.
                     if not Marked then
                        Action.Forward_Completed.Append (Action.From.Element (Index));
                        Files.History_Journal.Checkpoint (Model, Action, True);
                     end if;
                  else
                     if Marked then
                        --  Persist the invalidation before attempting to
                        --  recreate a missing publication. A crash must not
                        --  revive a marker that no longer describes Path.
                        Remove_Completion (Action, Action.From.Element (Index), True);
                        Files.History_Journal.Checkpoint (Model, Action, True);
                     end if;
                     if Source = "" or else not Exists_Safely (Source)
                       or else Exists_Safely (Dest)
                     then
                        Succeeded := False;
                     else
                        declare
                           Identity, Revision : Files.Types.UString;
                           Link_Source : constant Boolean :=
                             Action.Create_Kind = Files.Model.Create_Hard_Link
                               and then Hostkit.Fs.Is_Link (Source);
                           Source_Snapshot : constant String :=
                             (if Action.Create_Kind = Files.Model.Create_Hard_Link
                               and then not Link_Source
                              then Hard_Link_Snapshot (Source) else "");
                           Created : constant Boolean :=
                             (case Action.Create_Kind is
                                 when Files.Model.Create_Copy =>
                                   Files.File_System.Copy_Tree
                                     (Source, Dest, Identity, Revision, Copy_Batch).Success,
                                 when Files.Model.Create_Symbolic_Link =>
                                   Files.File_System.Create_Symbolic_Link (Source, Dest).Success,
                                 when Files.Model.Create_Hard_Link =>
                                   (if Link_Source or else Source_Snapshot /= ""
                                    then Files.File_System.Create_Hard_Link (Source, Dest).Success
                                    else False),
                                 when Files.Model.Create_None => False);
                        begin
                           if Created then
                              if Action.Create_Kind /= Files.Model.Create_Copy then
                                 Identity := To_Unbounded_String (Files.File_Identities.Token (Dest));
                                 Revision := To_Unbounded_String
                                   (if Action.Create_Kind = Files.Model.Create_Hard_Link
                                    then Source_Snapshot
                                    else Files.File_System.Tree_Revision (Dest));
                              end if;
                              while Action.Created_Identities.Last_Index < Index loop
                                 Action.Created_Identities.Append (Null_Unbounded_String);
                              end loop;
                              while Action.Created_Tree_Revisions.Last_Index < Index loop
                                 Action.Created_Tree_Revisions.Append (Null_Unbounded_String);
                              end loop;
                              Action.Created_Identities.Replace_Element
                                (Index, Identity);
                              Action.Created_Tree_Revisions.Replace_Element
                                (Index, Revision);
                              Action.Forward_Completed.Append (Action.From.Element (Index));
                              Action.Copy_Records := Files.Copy_Context.Records (Copy_Batch);
                              Files.History_Journal.Checkpoint (Model, Action, True);
                           else
                              Succeeded := False;
                           end if;
                        end;
                     end if;
                  end if;
               end;
            end loop;

         when Files.Model.Undo_Set_Permissions =>
            --  Re-apply the new mode stored in Forward.
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               if Files.Job_Context.Cancelled then
                  return False;
               end if;
               declare

                  New_Text : constant String :=
                    (if Index <= Action.Forward.Last_Index
                     then Ada.Strings.Fixed.Trim (To_String (Action.Forward.Element (Index)), Ada.Strings.Both)
                     else "");
                  New_Mode : Natural := 0;
               begin
                  if New_Text = "" then
                     Succeeded := False;
                  else
                     begin
                        New_Mode := Natural'Value (New_Text);
                     exception
                        when others =>
                           Succeeded := False;
                     end;

                     if (New_Mode > 0 or else New_Text = "0")
                       and then not Change_Recorded_Metadata (Action, Index, False, New_Mode)
                     then
                        Succeeded := False;
                     end if;
                  end if;
               end;
            end loop;

         when Files.Model.Undo_Set_Ownership =>
            --  Re-apply the new owner/group stored in Forward.
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               if Files.Job_Context.Cancelled then
                  return False;
               end if;
               declare

                  New_Text : constant String :=
                    (if Index <= Action.Forward.Last_Index
                     then Ada.Strings.Fixed.Trim (To_String (Action.Forward.Element (Index)), Ada.Strings.Both)
                     else "");
                  Space    : constant Natural :=
                    (if New_Text = "" then 0 else Ada.Strings.Fixed.Index (New_Text, " "));
                  New_Uid  : Natural := 0;
                  New_Gid  : Natural := 0;
               begin
                  if Space > 0 then
                     begin
                        New_Uid := Natural'Value (New_Text (New_Text'First .. Space - 1));
                        New_Gid := Natural'Value (New_Text (Space + 1 .. New_Text'Last));
                        if not Change_Recorded_Metadata (Action, Index, True, New_Uid, New_Gid) then
                           Succeeded := False;
                        end if;
                     exception
                        when others =>
                           Succeeded := False;
                     end;
                  else
                     Succeeded := False;
                  end if;
               end;
            end loop;

         when Files.Model.Undo_Restore_Trash | Files.Model.Undo_None =>
            Succeeded := False;
      end case;
      return Succeeded;
   end Apply_Forward;

   function Finish_Action
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Directory : String;
      Succeeded : Boolean) return Operation_Result
   is
      Error_Key : constant String := (if Succeeded then "" else "error.undo.failed");
   begin
      --  Finalize visible state before a helper captures the model revision.
      --  Updating the error after launch would invalidate this action's reload.
      Files.Model.Set_Error (Model, Error_Key);
      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
         pragma Unreferenced (Reload);
      begin
         null;
      end;
      if not Files.Model.Background_Transfers (Model) then
         --  Synchronous reloads can clear or replace the error; retain the
         --  history action's final status for headless callers as before.
         Files.Model.Set_Error (Model, Error_Key);
      end if;
      return Make_Result
        ((if Succeeded then Operation_Success else Operation_Failed), Error_Key, Directory);
   end Finish_Action;

   function Undo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Directory : constant String := Files.Model.Current_Path (Model);
      Action    : Files.Model.Undo_Entry;
      Found     : Boolean := False;
      Returned_Action : Boolean := False;
      Succeeded : Boolean;
   begin
      if Files.Model.Background_Transfers (Model) then
         return Files.Operation_Jobs.Start (Model, Settings, Files.Operation_Jobs.Undo);
      end if;
      Files.Model.Take_Undo (Model, Action, Found);
      if not Found then
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
      end if;

      Files.History_Journal.Checkpoint (Model, Action, False);
      Succeeded := Apply_Reverse (Action, Model);

      --  A fully reversed, redoable action moves onto the redo stack. If the
      --  reverse only partially applied, the entry goes back onto the undo
      --  stack instead of vanishing from history. Completed steps are retained
      --  so a retry only applies unfinished work, preserving restored originals.
      --  Mode/owner restores are idempotent. An undo-only
      --  action that fully succeeded is simply consumed.
      if not Succeeded then
         Files.Model.Push_Undo (Model, Action);
      elsif Action.Redoable then
         --  A subsequent redo starts a new Undo cycle for the full action.
         Action.Reverse_Completed.Clear;
         Action.Restores_Completed.Clear;
         Action.Forward_Completed.Clear;
         Action.Copy_Records.Clear;
         Files.Model.Push_Redo (Model, Action);
      end if;

      Returned_Action := True;
      return Finish_Action (Model, Settings, Directory, Succeeded);
   exception
      when others =>
         if Found and then not Returned_Action then
            Files.Model.Push_Undo (Model, Action);
         end if;
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
   end Undo_Last;

   function Redo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Directory : constant String := Files.Model.Current_Path (Model);
      Action    : Files.Model.Undo_Entry;
      Found     : Boolean := False;
      Returned_Action : Boolean := False;
      Succeeded : Boolean;
   begin
      if Files.Model.Background_Transfers (Model) then
         return Files.Operation_Jobs.Start (Model, Settings, Files.Operation_Jobs.Redo);
      end if;
      Files.Model.Take_Redo (Model, Action, Found);
      if not Found then
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
      end if;

      Files.History_Journal.Checkpoint (Model, Action, True);
      Succeeded := Apply_Forward (Action, Model);

      --  A fully re-applied action returns to the undo stack without disturbing
      --  the rest of the redo history. If it only partially applied, it goes
      --  back onto the redo stack with its completed steps, so retries only
      --  apply unfinished items. A full Redo starts a fresh Undo/Redo cycle.
      if Succeeded then
         Action.Forward_Completed.Clear;
         Files.Model.Push_Undo (Model, Action);
      else
         Files.Model.Push_Redo (Model, Action);
      end if;

      Returned_Action := True;
      return Finish_Action (Model, Settings, Directory, Succeeded);
   exception
      when others =>
         if Found and then not Returned_Action then
            Files.Model.Push_Redo (Model, Action);
         end if;
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
   end Redo_Last;

end History;
