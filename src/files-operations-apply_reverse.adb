separate (Files.Operations)
--  Apply the reverse (undo) direction of Action. Returns True on full
--  success. Mirrors the pre-existing single-level undo behaviour.
function Apply_Reverse
  (Action : in out Files.Model.Undo_Entry; Model : in out Files.Model.Window_Model)
   return Boolean
is
   Succeeded : Boolean := True;
   Reversed  : Path_Sets.Set := To_Set (Action.Reverse_Completed);

   --  Whether the item restored to Targets (Index) is the trashed one itself
   --  (a rename keeps its identity), so a retry recognises it there.
   function Restored_In_Place
     (Targets, Identities : Files.Types.String_Vectors.Vector; Index : Positive) return Boolean is
     (Files.Model.Value_At (Targets, Index) /= ""
      and then Files.Model.Value_At (Identities, Index) /= ""
      and then Files.File_Identities.Token (Files.Model.Value_At (Targets, Index))
        = Files.Model.Value_At (Identities, Index));
   Restored  : Path_Sets.Set := To_Set (Action.Restores_Completed);
begin
   --  Copies a failed move kept beside their sources leave first: before
   --  anything moves back, and before an original a replace preserved is
   --  restored to the path one of them holds. Each step is marked, so a
   --  retry never deletes what a restore has since put there.
   for Index in Action.Kept_Copies.First_Index .. Action.Kept_Copies.Last_Index loop
      if Files.Job_Context.Cancelled then
         return False;
      end if;
      declare
         Target : constant String := To_String (Action.Kept_Copies (Index));
         Identity : constant String := Files.Model.Kept_Copy_Identity (Action, Index);
         Tree_Revision : constant String := Files.Model.Kept_Copy_Tree_Revision (Action, Index);
      begin
         if Reversed.Contains (Target) then
            null;
         elsif Exists_Safely (Target)
           and then (Identity = ""
             or else Files.File_Identities.Token (Target) /= Identity
             or else not Files.File_System.Delete_Created_Entry (Target, Identity, Tree_Revision).Success)
         then
            Succeeded := False;
         else
            Action.Reverse_Completed.Append (Action.Kept_Copies (Index));
            Reversed.Include (Target);
            Files.History_Journal.Checkpoint (Model, Action, False);
         end if;
      end;
   end loop;
   --  An original goes back only to a path no kept copy still holds.
   if not Succeeded then
      return False;
   end if;

   case Action.Kind is
      when Files.Model.Undo_Rename | Files.Model.Undo_Move =>
         Succeeded := Move_Back (Action, Model, False);

      when Files.Model.Undo_Restore_Trash =>
         for Index in Action.From.First_Index .. Action.From.Last_Index loop
            if Files.Job_Context.Cancelled then
               return False;
            end if;
            if Reversed.Contains (To_String (Action.From.Element (Index))) then
               null;
            elsif not Restore_Recorded_Trash (Action.From (Index), Action.Created_Identities, Action.To, Index)
            then
               Succeeded := False;
            else
               --  Its labels come back out of the trash with it.
               if Files.Model.To_Value (Action, Index) /= "" then
                  Files.Model.Note_Path_Move
                    (Model, To_String (Action.From (Index)), Files.Model.To_Value (Action, Index));
               end if;
               Action.Reverse_Completed.Append (Action.From.Element (Index));
               Reversed.Include (To_String (Action.From.Element (Index)));
               --  A retry finds a finished restore by its identity at the
               --  original path (Restore_Recorded_Trash) -- unless it was a
               --  copy across devices, which has a new one: written now.
               Files.History_Journal.Checkpoint
                 (Model, Action, False,
                  Force => not Restored_In_Place (Action.To, Action.Created_Identities, Index));
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
               Expected_Identity : constant String := Files.Model.Created_Identity (Action, Index);
               Expected_Tree_Revision : constant String := Files.Model.Created_Tree_Revision (Action, Index);
            begin
               if Reversed.Contains (To_String (Action.From.Element (Index))) then
                  null;
               elsif Exists_Safely (Target)
                 and then (Expected_Identity = ""
                           or else Files.File_Identities.Token (Target) /= Expected_Identity)
               then
                  Succeeded := False;
               elsif Exists_Safely (Target)
                 and then not Files.File_System.Delete_Created_Entry
                   (Target, Expected_Identity, Expected_Tree_Revision).Success
               then
                  Succeeded := False;
               else
                  Action.Reverse_Completed.Append (Action.From.Element (Index));
                  Reversed.Include (To_String (Action.From.Element (Index)));
                  --  A retry treats a path already gone as removed.
                  Files.History_Journal.Checkpoint (Model, Action, False, Force => False);
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
            declare
               --  A malformed entry (To shorter than From) reads "", which
               --  does not parse: that item fails.
               Old_Text : constant String :=
                 Ada.Strings.Fixed.Trim (Files.Model.To_Value (Action, Index), Ada.Strings.Both);
               Old_Mode : Natural := 0;
            begin
               --  The access record, where one was kept, is put back
               --  whole: on Windows the DACL the change replaced.
               if not Files.Undo_Payloads.Parse_Mode (Old_Text, Old_Mode)
                 or else not Change_Recorded_Mode
                   (Action, Index, Old_Mode, Files.Undo_Payloads.Mode_Access (Old_Text))
               then
                  Succeeded := False;
               end if;
            end;
         end loop;

      when Files.Model.Undo_Set_Ownership =>
         --  Restore the previous owner/group recorded before the chown.
         --  From holds the path and To holds "uid gid" decimal images.
         for Index in Action.From.First_Index .. Action.From.Last_Index loop
            if Files.Job_Context.Cancelled then
               return False;
            end if;
            declare
               Old_Text : constant String :=
                 Ada.Strings.Fixed.Trim (Files.Model.To_Value (Action, Index), Ada.Strings.Both);
               Old_Uid  : Files.Types.Account_Id := 0;
               Old_Gid  : Files.Types.Account_Id := 0;
               Old_User_Name, Old_Group_Name : Files.Types.UString;
            begin
               if Parse_Ownership_Text
                 (Old_Text, Old_Uid, Old_Gid,
                  Old_User_Name, Old_Group_Name)
               then
                  if not Change_Recorded_Ownership
                    (Action, Index, Old_Uid, Old_Gid,
                     To_String (Old_User_Name),
                     To_String (Old_Group_Name))
                  then
                     Succeeded := False;
                  end if;
               else
                  Succeeded := False;
               end if;
            end;
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
      if Restored.Contains (To_String (Action.Restore_Trash.Element (Index))) then
         null;
      elsif not Restore_Recorded_Trash
                 (Action.Restore_Trash (Index), Action.Restore_Identities, Action.Restore_Targets, Index)
      then
         Succeeded := False;
      else
         Action.Restores_Completed.Append (Action.Restore_Trash.Element (Index));
         Restored.Include (To_String (Action.Restore_Trash.Element (Index)));
         Files.History_Journal.Checkpoint
           (Model, Action, False,
            Force => not Restored_In_Place (Action.Restore_Targets, Action.Restore_Identities, Index));
      end if;
   end loop;

   return Succeeded;
end Apply_Reverse;
