separate (Files_Suite.Operations)
   procedure Test_Trash_History_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "entry");
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Paths : Files.Types.String_Vectors.Vector;
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
      Selected : Boolean;
   begin
      for Background in Boolean loop
         for Replace in Boolean loop
            Reset_Root;
            Write_Binary_File (Source, "original destination");
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            if Replace then
               Ada.Directories.Create_Directory (Join (Root, "inbox"));
               Write_Binary_File (Join (Root, "inbox/entry"), "pasted bytes");
               Actions.Clear;
               Actions.Append (Files.Paste.Resolved_Action'
                 (To_Unbounded_String (Join (Root, "inbox/entry")), To_Unbounded_String (Source), False, True));
               Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy, False);
               Step := Complete_Operation
                 (Model, Settings, Files.Operations.Advance_Paste_Execution (Model, Settings, 1));
               Await_View (Model, Settings);
               Paths := Files.Model.Undo_History (Model).Last_Element.Restore_Trash;
            else
               Selected := Files.Model.Select_By_Name (Model, "entry");
               Assert (Selected, "select the trash fixture");
               Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected (Model, Settings));
               Await_View (Model, Settings);
               Paths := Files.Model.Undo_From_Paths (Model);
            end if;
            Assert (Step.Status = Files.Operations.Operation_Success and then not Paths.Is_Empty,
                    "trash or paste-replace records recoverable history");
            declare
               Payload : constant String := To_String (Paths.First_Element);
               Saved : constant String := Payload & "-saved";
            begin
               Assert (Hostkit.Fs.Move_No_Replace (Payload, Saved), "hold the owned trash payload");
               Write_Binary_File (Payload, "unrelated replacement");
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Files_Suite.Support.Assert_Equal
                 (Step.Status,
                  Files.Operations.Operation_Failed,
                  "Undo refuses to restore an unrelated trash payload and retains retryable history: status");
               Assert
                 (Files.Model.Undo_Available (Model),
                  "Undo refuses to restore an unrelated trash payload and retains retryable history: undo kept");
               Assert
                 (File_Has_Bytes (Payload, "unrelated replacement"),
                  "Undo refuses to restore an unrelated trash payload and retains retryable history: replacement kept");
               Assert
                 (not Ada.Directories.Exists (Source),
                  "Undo refuses to restore an unrelated trash payload and retains retryable history"
                  & ": source not created");
               Mutation := Files.File_System.Delete_Permanently (Payload);
               Assert (Mutation.Success and then Hostkit.Fs.Move_No_Replace (Saved, Payload),
                       "put the original trash payload back");
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success
                       and then File_Has_Bytes (Source, "original destination"),
                       "retry restores the original without repeating completed paste removal");
            end;
         end loop;
      end loop;
   end Test_Trash_History_Identity;
