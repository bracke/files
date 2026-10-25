separate (Files_Suite.Operations)
   procedure Test_Paste_Undo_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
   begin
      for Mode in Files.File_System.Drop_Import_Mode loop
         for Background in Boolean loop
            Reset_Root;
            Ada.Directories.Create_Directory (Join (Root, "inbox"));
            Write_Binary_File (Join (Join (Root, "inbox"), "a.txt"), "a bytes");
            Write_Binary_File (Join (Join (Root, "inbox"), "b.txt"), "b bytes");
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Operations.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            declare
               Actions : Files.Paste.Resolved_Action_Vectors.Vector;
               A : constant String := Join (Root, "a.txt");
               B : constant String := Join (Root, "b.txt");
               Saved_A : constant String := Join (Root, "saved-a.txt");
            begin
               Actions.Append (Files.Paste.Resolved_Action'
                 (To_Unbounded_String (Join (Join (Root, "inbox"), "a.txt")), To_Unbounded_String (A), False, False));
               Actions.Append (Files.Paste.Resolved_Action'
                 (To_Unbounded_String (Join (Join (Root, "inbox"), "b.txt")), To_Unbounded_String (B), False, False));
               Files.Model.Begin_Paste_Execution (Model, Actions, Mode, False);
               for Attempt in Files_Suite.Support.Polling loop
                  Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
                  exit when Files.Model.Paste_Execution_Done (Model) = 1;
               end loop;
               Files_Suite.Support.Assert_Equal
                 (Files.Model.Paste_Execution_Done (Model),
                  1,
                  "the first paste member commits");
               Assert (Hostkit.Fs.Move_No_Replace (A, Saved_A), "retain the first owned entry between batches");
               Write_Binary_File (A, "unrelated a");
               Step := Complete_Operation (Model, Settings, Step);
               Await_View (Model, Settings);
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Files_Suite.Support.Assert_Equal
                 (Step.Status,
                  Files.Operations.Operation_Failed,
                  "later paste steps cannot recapture a replacement as an owned entry: status");
               Assert
                 (File_Has_Bytes (A, "unrelated a"),
                  "later paste steps cannot recapture a replacement as an owned entry: A replacement kept");
               Assert
                 (not Ada.Directories.Exists (B),
                  "later paste steps cannot recapture a replacement as an owned entry: B not created");
               Mutation := Files.File_System.Delete_Permanently (A);
               Assert (Mutation.Success and then Hostkit.Fs.Move_No_Replace (Saved_A, A),
                       "restore the owned first entry");
               Write_Binary_File (B, "unrelated b");
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Files_Suite.Support.Assert_Equal
                 (Step.Status,
                  Files.Operations.Operation_Success,
                  "partial Undo retries preserve unrelated entries at already reversed paths: status");
               Assert
                 (not Ada.Directories.Exists (A),
                  "partial Undo retries preserve unrelated entries at already reversed paths: A removed");
               Assert
                 (File_Has_Bytes (B, "unrelated b"),
                  "partial Undo retries preserve unrelated entries at already reversed paths: B replacement kept");
            end;
         end loop;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Paste_Undo_Identity;
