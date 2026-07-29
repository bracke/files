with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Files.File_System;
with Files.Types;

with Files.Operations.Support;

separate (Files.Operations)
package body History is
   use type Files.Model.Undo_Action_Kind;

   function Move_Back
     (Sources : Files.Types.String_Vectors.Vector;
      Targets : Files.Types.String_Vectors.Vector)
      return Boolean
   is
      Succeeded : Boolean := True;
   begin
      for Index in Sources.First_Index .. Sources.Last_Index loop
         declare
            Source : constant String := To_String (Sources.Element (Index));
            Target : constant String := To_String (Targets.Element (Index));
         begin
            if Exists_Safely (Source) and then not Exists_Safely (Target) then
               if not Files.File_System.Rename_Item (Source, Target).Success then
                  Succeeded := False;
               end if;
            elsif not Exists_Safely (Source) and then Exists_Safely (Target) then
               --  Already moved back by an earlier, partially-applied pass: the
               --  source is gone and the target is in place. Treat it as an
               --  idempotent success (this is the "missing paths count as
               --  already undone" invariant Undo_Last documents) so that
               --  re-running a partially-applied multi-item undo can finish the
               --  items that were previously blocked, instead of the
               --  already-restored ones forcing failure forever.
               null;
            else
               --  Source still present with the target occupied, or both gone:
               --  this item cannot be moved back right now.
               Succeeded := False;
            end if;
         end;
      end loop;
      return Succeeded;
   end Move_Back;

   --  Apply the reverse (undo) direction of Action. Returns True on full
   --  success. Mirrors the pre-existing single-level undo behaviour.
   function Apply_Reverse
     (Action : Files.Model.Undo_Entry)
      return Boolean
   is
      Succeeded : Boolean := True;
   begin
      case Action.Kind is
         when Files.Model.Undo_Rename | Files.Model.Undo_Move =>
            Succeeded := Move_Back (Action.From, Action.To);

         when Files.Model.Undo_Restore_Trash =>
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               if not Files.File_System.Restore_From_Trash
                        (To_String (Action.From.Element (Index))).Success
               then
                  Succeeded := False;
               end if;
            end loop;

         when Files.Model.Undo_Delete_Created =>
            --  Undo a created path by removing it again. Missing paths are
            --  treated as already undone.
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               declare
                  Target : constant String := To_String (Action.From.Element (Index));
               begin
                  if Exists_Safely (Target)
                    and then not Files.File_System.Delete_Permanently (Target).Success
                  then
                     Succeeded := False;
                  end if;
               end;
            end loop;

         when Files.Model.Undo_Set_Permissions =>
            --  Restore the previous mode recorded before the chmod. From holds
            --  the path and To holds the decimal image of the old mode bits.
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               if Index > Action.To.Last_Index then
                  --  Malformed entry: To shorter than From. Fail this item
                  --  rather than index out of range (mirrors the forward guard).
                  Succeeded := False;
               else
                  declare
                     Target   : constant String := To_String (Action.From.Element (Index));
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
                        if not Files.File_System.Set_Permissions (Target, Old_Mode).Success then
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
               if Index > Action.To.Last_Index then
                  Succeeded := False;
               else
                  declare
                     Target   : constant String := To_String (Action.From.Element (Index));
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
                           if not Files.File_System.Set_Ownership (Target, Old_Uid, Old_Gid).Success then
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
         if not Files.File_System.Restore_From_Trash
                  (To_String (Action.Restore_Trash.Element (Index))).Success
         then
            Succeeded := False;
         end if;
      end loop;

      return Succeeded;
   end Apply_Reverse;

   --  Apply the forward (redo) direction of Action. Returns True on full
   --  success. Undo_Restore_Trash is undo-only and never reaches here.
   function Apply_Forward
     (Action : Files.Model.Undo_Entry)
      return Boolean
   is
      Succeeded : Boolean := True;
   begin
      case Action.Kind is
         when Files.Model.Undo_Rename | Files.Model.Undo_Move =>
            --  Re-run the original transition: from the reverted (To) location
            --  back to the post-operation (From) location.
            Succeeded := Move_Back (Action.To, Action.From);

         when Files.Model.Undo_Delete_Created =>
            --  Re-create each destination from its recorded source using the
            --  stored creation kind.
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               declare
                  Dest   : constant String := To_String (Action.From.Element (Index));
                  Source : constant String :=
                    (if Index <= Action.Forward.Last_Index
                     then To_String (Action.Forward.Element (Index))
                     else "");
               begin
                  if Source = ""
                    or else not Exists_Safely (Source)
                    or else Exists_Safely (Dest)
                  then
                     Succeeded := False;
                  else
                     case Action.Create_Kind is
                        when Files.Model.Create_Copy =>
                           if not Files.File_System.Copy_Tree (Source, Dest).Success then
                              Succeeded := False;
                           end if;
                        when Files.Model.Create_Symbolic_Link =>
                           if not Files.File_System.Create_Symbolic_Link (Source, Dest).Success then
                              Succeeded := False;
                           end if;
                        when Files.Model.Create_Hard_Link =>
                           if not Files.File_System.Create_Hard_Link (Source, Dest).Success then
                              Succeeded := False;
                           end if;
                        when Files.Model.Create_None =>
                           Succeeded := False;
                     end case;
                  end if;
               end;
            end loop;

         when Files.Model.Undo_Set_Permissions =>
            --  Re-apply the new mode stored in Forward.
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               declare
                  Target   : constant String := To_String (Action.From.Element (Index));
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
                       and then not Files.File_System.Set_Permissions (Target, New_Mode).Success
                     then
                        Succeeded := False;
                     end if;
                  end if;
               end;
            end loop;

         when Files.Model.Undo_Set_Ownership =>
            --  Re-apply the new owner/group stored in Forward.
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               declare
                  Target   : constant String := To_String (Action.From.Element (Index));
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
                        if not Files.File_System.Set_Ownership (Target, New_Uid, New_Gid).Success then
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

   function Undo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Directory : constant String := Files.Model.Current_Path (Model);
      Action    : Files.Model.Undo_Entry;
      Found     : Boolean;
      Succeeded : Boolean;
   begin
      Files.Model.Take_Undo (Model, Action, Found);
      if not Found then
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
      end if;

      Succeeded := Apply_Reverse (Action);

      --  A fully reversed, redoable action moves onto the redo stack. If the
      --  reverse only partially applied, the entry goes back onto the undo
      --  stack instead of vanishing from history: re-running is safe (missing
      --  paths count as already undone and mode/owner restores are idempotent)
      --  and lets the user retry the items that did not revert. An undo-only
      --  action that fully succeeded is simply consumed.
      if not Succeeded then
         Files.Model.Push_Undo (Model, Action);
      elsif Action.Redoable then
         Files.Model.Push_Redo (Model, Action);
      end if;

      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
         pragma Unreferenced (Reload);
      begin
         null;
      end;

      if not Succeeded then
         Files.Model.Set_Error (Model, "error.undo.failed");
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
      end if;

      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Success, Path => Directory);
   exception
      when others =>
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
   end Undo_Last;

   function Redo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Directory : constant String := Files.Model.Current_Path (Model);
      Action    : Files.Model.Undo_Entry;
      Found     : Boolean;
      Succeeded : Boolean;
   begin
      Files.Model.Take_Redo (Model, Action, Found);
      if not Found then
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
      end if;

      Succeeded := Apply_Forward (Action);

      --  A fully re-applied action returns to the undo stack without disturbing
      --  the rest of the redo history. If it only partially applied, it goes
      --  back onto the redo stack rather than being dropped, so the redo stays
      --  available for a retry (Apply_Forward's Exists_Safely guards keep a
      --  retry from overwriting the items that already re-applied).
      if Succeeded then
         Files.Model.Push_Undo (Model, Action);
      else
         Files.Model.Push_Redo (Model, Action);
      end if;

      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
         pragma Unreferenced (Reload);
      begin
         null;
      end;

      if not Succeeded then
         Files.Model.Set_Error (Model, "error.undo.failed");
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
      end if;

      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Success, Path => Directory);
   exception
      when others =>
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
   end Redo_Last;

end History;
