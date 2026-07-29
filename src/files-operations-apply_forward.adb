separate (Files.Operations)
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
