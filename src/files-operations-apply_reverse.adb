separate (Files.Operations)
--  Apply the reverse (undo) direction of Action. Returns True on full
--  success. Mirrors the pre-existing single-level undo behaviour.
function Apply_Reverse
  (Action : in out Files.Model.Undo_Entry; Model : in out Files.Model.Window_Model)
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
               --  Its labels come back out of the trash with it.
               if Index <= Action.To.Last_Index then
                  Files.Model.Note_Path_Move
                    (Model, To_String (Action.From (Index)), To_String (Action.To (Index)));
               end if;
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
                  Old_Uid  : Natural := 0;
                  Old_Gid  : Natural := 0;
                  Old_User_Name, Old_Group_Name : Files.Types.UString;
               begin
                  if Parse_Ownership_Text
                    (Old_Text, Old_Uid, Old_Gid,
                     Old_User_Name, Old_Group_Name)
                  then
                     if not Change_Recorded_Metadata
                       (Action, Index, True, Old_Uid, Old_Gid,
                        To_String (Old_User_Name),
                        To_String (Old_Group_Name))
                     then
                        Succeeded := False;
                     end if;
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
