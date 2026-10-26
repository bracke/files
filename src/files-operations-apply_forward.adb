separate (Files.Operations)
--  Apply the forward (redo) direction of Action. Returns True on full
--  success. Undo_Restore_Trash is undo-only and never reaches here.
function Apply_Forward
  (Action : in out Files.Model.Undo_Entry; Model : in out Files.Model.Window_Model)
   return Boolean
is
   Succeeded : Boolean := True;
   Copy_Batch : Files.Copy_Context.Session;
   Forwarded  : Path_Sets.Set := To_Set (Action.Forward_Completed);
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
                 Forwarded.Contains (To_String (Action.From.Element (Index)));
               Matches : constant Boolean :=
                 Completed_Creation_Matches (Action, Index, Dest);
            begin
               if Matches then
                  --  A helper may have published the entry before its
                  --  completion marker reached the history journal.
                  if not Marked then
                     Action.Forward_Completed.Append (Action.From.Element (Index));
                     Forwarded.Include (To_String (Action.From.Element (Index)));
                     Files.History_Journal.Checkpoint (Model, Action, True);
                  end if;
               else
                  if Marked then
                     --  Persist the invalidation before attempting to
                     --  recreate a missing publication. A crash must not
                     --  revive a marker that no longer describes Path.
                     Remove_Completion (Action, Action.From.Element (Index), True);
                     Forwarded.Exclude (To_String (Action.From.Element (Index)));
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
                                 elsif Action.Create_Kind = Files.Model.Create_Symbolic_Link
                                 then ""
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
                           Forwarded.Include (To_String (Action.From.Element (Index)));
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
                    and then not Change_Recorded_Mode (Action, Index, New_Mode)
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
               New_Uid  : Files.Types.Account_Id := 0;
               New_Gid  : Files.Types.Account_Id := 0;
               New_User_Name, New_Group_Name : Files.Types.UString;
            begin
               if Parse_Ownership_Text
                 (New_Text, New_Uid, New_Gid,
                  New_User_Name, New_Group_Name)
               then
                  if not Change_Recorded_Ownership
                    (Action, Index, New_Uid, New_Gid,
                     To_String (New_User_Name),
                     To_String (New_Group_Name))
                  then
                     Succeeded := False;
                  end if;
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
