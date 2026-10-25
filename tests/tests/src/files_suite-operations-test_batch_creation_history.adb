separate (Files_Suite.Operations)
   procedure Test_Batch_Creation_History (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Zlib.Status_Code;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Status : Zlib.Status_Code;
      Prior : Files.Types.String_Vectors.Vector;
      Created : Files.Types.String_Vectors.Vector;
   begin
      for Background in Boolean loop
         for Extracting in Boolean loop
            for Partial in Boolean loop
               Reset_Root;
               Write_Binary_File (Join (Root, "a.txt"), "a bytes");
               Write_Binary_File (Join (Root, "b.txt"), "b bytes");
               Write_Binary_File (Join (Root, "prior"), "prior action");
               if Extracting then
                  Zlib.ZIP_File (Join (Root, "a.txt"), Join (Root, "a.zip"), "a.txt", Status => Status);
                  Assert (Status = Zlib.Ok, "prepare first archive");
                  Zlib.ZIP_File (Join (Root, "b.txt"), Join (Root, "b.zip"), "b.txt", Status => Status);
                  Assert (Status = Zlib.Ok, "prepare second archive");
               end if;
               Load := Files.File_System.Load_Directory (Root, Settings);
               Files.Model.Initialize (Model, Root, Load.Items, Root);
               Files.Model.Clear_Undo (Model);
               Prior.Clear;
               Prior.Append (To_Unbounded_String (Join (Root, "prior")));
               Files.Model.Record_Undo
                 (Model, Files.Model.Undo_Delete_Created, Prior, Files.Types.String_Vectors.Empty_Vector,
                  Redoable => False);
               Files.Model.Set_Filter (Model, (if Extracting then ".zip" else ".txt"));
               Files.Model.Select_All_Visible (Model);
               Files.Model.Set_Background_Transfers (Model, Background);
               if Partial then
                  if Extracting then
                     Write_Binary_File (Join (Root, "b.zip"), "invalid archive");
                  else
                     Ada.Directories.Delete_File (Join (Root, "b.txt"));
                  end if;
               end if;
               Step := Complete_Operation
                 (Model, Settings, (if Extracting then Files.Operations.Extract_Selected (Model, Settings)
                                    else Files.Operations.Duplicate_Selected (Model, Settings)));
               Await_View (Model, Settings);
               Created := Files.Model.Undo_From_Paths (Model);
               Files_Suite.Support.Assert_Equal
                 (Step.Status,
                  (if Partial then Files.Operations.Operation_Failed else Files.Operations.Operation_Success),
                  "successful and partial batches add one action without replacing prior history: status");
               Files_Suite.Support.Assert_Equal
                 (Natural (Files.Model.Undo_History (Model).Length),
                  2,
                  "successful and partial batches add one action without replacing prior history: history length");
               Files_Suite.Support.Assert_Equal
                 (Natural (Created.Length),
                  (if Partial then 1 else 2),
                  "successful and partial batches add one action without replacing prior history: created paths");
               if Partial then
                  declare
                     Expected_Name : constant String :=
                       (if Extracting then "a" else "a (copy).txt");
                     Found : Boolean := False;
                  begin
                     --  The first item committed before the second failed. It
                     --  must be present in the refreshed model, not merely on
                     --  disk and in the Undo entry.
                     Files.Model.Set_Filter (Model, "");
                     for Index in 1 .. Files.Model.Visible_Count (Model) loop
                        Found := Found or else
                          To_String (Files.Model.Visible_Item (Model, Index).Name) = Expected_Name;
                     end loop;
                     Assert
                       (Found
                        and then Files.Model.Last_Error_Key (Model) =
                          (if Extracting then "error.extract.failed" else "error.duplicate.failed"),
                        "partial batches refresh committed outputs and retain their diagnostic");
                  end;
               end if;
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               for Path of Created loop
                  Assert (not Ada.Directories.Exists (To_String (Path)),
                          "one Undo removes every committed batch member");
               end loop;
               declare
                  Replacement : constant String := To_String (Created.First_Element);
                  Keep : constant String := (if Extracting then Join (Replacement, "keep.txt") else Replacement);
               begin
                  if Extracting then
                     Ada.Directories.Create_Directory (Replacement);
                  end if;
                  Write_Binary_File (Keep, "unrelated replacement");
                  Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                  Await_View (Model, Settings);
                  Files_Suite.Support.Assert_Equal
                    (Step.Status,
                     Files.Operations.Operation_Success,
                     "the next Undo reaches the prior action and never touches a recreated batch path: status");
                  Assert (not Files.Model.Undo_Available (Model),
                          "the next Undo reaches the prior action and never touches a recreated batch path: "
                          & "history empty");
                  Assert (not Ada.Directories.Exists (Join (Root, "prior")),
                          "the next Undo reaches the prior action and never touches a recreated batch path: "
                          & "prior action undone");
                  Assert (File_Has_Bytes (Keep, "unrelated replacement"),
                          "the next Undo reaches the prior action and never touches a recreated batch path: "
                          & "replacement kept");
               end;
            end loop;
         end loop;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Batch_Creation_History;
