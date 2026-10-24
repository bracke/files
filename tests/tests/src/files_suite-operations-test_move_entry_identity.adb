separate (Files_Suite.Operations)
   procedure Test_Move_Entry_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Source : constant String := Join (Root, "original");
      Dest : constant String := Join (Root, "renamed");
      Saved : constant String := Join (Root, "saved-original");
      Link_Target : constant String := Join (Root, "link-target");
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;

      procedure Replace_And_Refuse (Path : String; Forward : Boolean) is
      begin
         Assert (Hostkit.Fs.Move_No_Replace (Path, Saved), "retain the owned history entry");
         Write_Binary_File (Path, "unrelated replacement");
         Step := Complete_Operation (Model, Settings,
           (if Forward then Files.Operations.Redo_Last (Model, Settings)
            else Files.Operations.Undo_Last (Model, Settings)));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Failed
                 and then File_Has_Bytes (Path, "unrelated replacement"), "history refuses to move a replacement");
         Mutation := Files.File_System.Delete_Permanently (Path);
         Assert (Mutation.Success and then Hostkit.Fs.Move_No_Replace (Saved, Path), "restore the owned history entry");
      end Replace_And_Refuse;
   begin
      for Background in Boolean loop
         for Paste_Move in Boolean loop
            for Kind in 1 .. 3 loop
               Reset_Root;
               Write_Binary_File (Link_Target, "target bytes");
               case Kind is
                  when 1 => Write_Binary_File (Source, "owned bytes");
                  when 2 =>
                     Ada.Directories.Create_Directory (Source);
                     Write_Binary_File (Join (Source, "child"), "owned bytes");
                  when others =>
                     if not Hostkit.Fs.Create_Link (Link_Target, Source) then
                        return;
                     end if;
               end case;
               Load := Files.File_System.Load_Directory (Root, Settings);
               Files.Model.Initialize (Model, Root, Load.Items, Root);
               Files.Model.Clear_Undo (Model);
               Files.Model.Set_Background_Transfers (Model, Background);
               if Paste_Move then
                  Actions.Clear;
                  Actions.Append (Files.Paste.Resolved_Action'
                    (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, False));
                  Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Move, False);
                  Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
               else
                  Select_Name (Model, "original");
                  Files.Commands.Execute (Files.Commands.Rename_Selected_Items_Command, Model);
                  Files.Model.Set_Rename_Text (Model, "renamed");
                  Step := Files.Operations.Commit_Rename (Model, Settings);
               end if;
               Step := Complete_Operation (Model, Settings, Step);
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success, "the initial history move succeeds");
               Replace_And_Refuse (Dest, False);
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success, "Undo can retry the restored entry");
               Replace_And_Refuse (Source, True);
               Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success, "Redo can retry the restored entry");
               --  A vanished source and an unrelated target are not evidence
               --  that the history transition already completed.
               Assert (Hostkit.Fs.Move_No_Replace (Dest, Saved), "remove the owned source pathname");
               Write_Binary_File (Source, "unrelated target");
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Failed and then Files.Model.Undo_Available (Model)
                       and then File_Has_Bytes (Source, "unrelated target"),
                       "history cannot mark an unrelated existing target as already moved");
            end loop;
         end loop;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Move_Entry_Identity;
