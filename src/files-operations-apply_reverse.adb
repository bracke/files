separate (Files.Operations)
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
            end loop;

         when Files.Model.Undo_Set_Ownership =>
            --  Restore the previous owner/group recorded before the chown.
            --  From holds the path and To holds "uid gid" decimal images.
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
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
