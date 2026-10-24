separate (Files_Suite.Operations)
   procedure Test_Undo_Entry_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Source : constant String := Join (Root, "original");
      Dest : constant String := Join (Root, "original (copy)");
      Old_Dest : constant String := Join (Root, "old-copy");
      Target : constant String := Join (Root, "target");
      Old_Token : Unbounded_String;
   begin
      for Background in Boolean loop
         for Kind in 1 .. 3 loop
            Reset_Root;
            Write_Binary_File (Target, "target bytes");
            case Kind is
               when 1 => Write_Binary_File (Source, "same bytes");
               when 2 =>
                  Ada.Directories.Create_Directory (Source);
                  Write_Binary_File (Join (Source, "child"), "same bytes");
                  GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
                    (Source, GNAT.OS_Lib.GM_Time_Of (2022, 3, 4, 5, 6, 8));
               when others =>
                  if not Hostkit.Fs.Create_Link (Target, Source) then
                     return;
                  end if;
            end case;
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            Select_Name (Model, "original");
            Step := Complete_Operation (Model, Settings, Files.Operations.Duplicate_Selected (Model, Settings));
            Await_View (Model, Settings);
            Old_Token := To_Unbounded_String (Files.File_Identities.Token (Dest));
            Assert (Length (Old_Token) > 0, "record a non-following entry identity");
            if Kind = 2 then
               Write_Binary_File (Join (Dest, "user-added"), "new user bytes");
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Failed
                       and then Files.Model.Undo_Available (Model)
                       and then File_Has_Bytes (Join (Dest, "child"), "same bytes")
                       and then File_Has_Bytes (Join (Dest, "user-added"), "new user bytes"),
                       "Undo refuses a copied directory after a user adds a child and retains the complete tree");
               Ada.Directories.Delete_File (Join (Dest, "user-added"));
               GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
                 (Dest, GNAT.OS_Lib.GM_Time_Of (2022, 3, 4, 5, 6, 8));
            end if;
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then not (Ada.Directories.Exists (Dest) or else Hostkit.Fs.Is_Link (Dest)),
                    "Undo removes the entry it created");
            Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "Redo republishes the entry");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success,
                    "Undo uses the new identity recorded by Redo");
            Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Hostkit.Fs.Move_No_Replace (Dest, Old_Dest), "retain the original inode at another path");
            Mutation := Files.File_System.Copy_Tree (Source, Dest);
            Assert (Mutation.Success, "replace the pathname with an identical but unrelated entry");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Failed
                    and then Files.Model.Undo_Available (Model)
                    and then (Ada.Directories.Exists (Dest) or else Hostkit.Fs.Is_Link (Dest)),
                    "Undo refuses a replacement even when its contents and link target are identical");
            Mutation := Files.File_System.Delete_Permanently (Dest);
            Assert (Mutation.Success and then Hostkit.Fs.Move_No_Replace (Old_Dest, Dest),
                    "put the owned entry back so the action can be retried");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success and then not Files.Model.Undo_Available (Model),
                    "a refused Undo remains retryable when its owned entry is restored");
         end loop;
         Reset_Root;
         Write_Binary_File (Source, "copied bytes");
         GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
           (Source, GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5));
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Select_Name (Model, "original");
         Step := Complete_Operation (Model, Settings, Files.Operations.Duplicate_Selected (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success
                 and then Files.File_System.Tree_Revision (Dest) /= "",
                 "a copied regular file has a recorded revision");
         Old_Token := To_Unbounded_String (Files.File_Identities.Token (Dest));
         declare
            Stamp : constant GNAT.OS_Lib.OS_Time := GNAT.OS_Lib.File_Time_Stamp (Dest);
            Metadata : constant String := Files.File_Identities.Revision (Dest, False);
            Snapshot : constant String := Files.File_System.Tree_Revision (Dest);
         begin
            Write_Binary_File (Dest, "edited bytes");
            GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Dest, Stamp);
            Assert (Files.File_Identities.Token (Dest) = To_String (Old_Token)
                    and then Files.File_Identities.Revision (Dest, False) = Metadata
                    and then Files.File_System.Tree_Revision (Dest) /= Snapshot,
                    "a same-size edit with restored mtime keeps its old metadata but changes its content digest");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Failed
                    and then Files.Model.Undo_Available (Model)
                    and then File_Has_Bytes (Dest, "edited bytes"),
                    "Undo retains a same-size edited copy and its retryable action");
         end;
         Reset_Root;
         Ada.Directories.Create_Directory (Source);
         Write_Binary_File (Join (Source, "child"), "copied bytes");
         GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
           (Join (Source, "child"), GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5));
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Select_Name (Model, "original");
         Step := Complete_Operation (Model, Settings, Files.Operations.Duplicate_Selected (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success,
                 "duplicate a directory containing a regular file");
         declare
            Child : constant String := Join (Dest, "child");
            Stamp : constant GNAT.OS_Lib.OS_Time := GNAT.OS_Lib.File_Time_Stamp (Child);
            Metadata : constant String := Files.File_Identities.Revision (Child, False);
            Snapshot : constant String := Files.File_System.Tree_Revision (Dest);
         begin
            Write_Binary_File (Child, "edited bytes");
            GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Child, Stamp);
            Assert (Files.File_Identities.Revision (Child, False) = Metadata
                    and then Files.File_System.Tree_Revision (Dest) /= Snapshot,
                    "a copied directory revision tracks same-size edits to a child");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Failed
                    and then Files.Model.Undo_Available (Model)
                    and then File_Has_Bytes (Child, "edited bytes"),
                    "Undo retains a copied directory whose child bytes changed");
         end;
      end loop;
      Reset_Root;
      declare
         Unverifiable : constant String := Join (Root, "unverifiable");
         Verifiable   : constant String := Join (Root, "verifiable");
         Older        : constant String := Join (Root, "older");
         Paths, Identities, Revisions, Older_Path : Files.Types.String_Vectors.Vector;
         Recorded : Boolean;
      begin
         Write_Binary_File (Unverifiable, "unverifiable bytes");
         Write_Binary_File (Verifiable, "verifiable bytes");
         Write_Binary_File (Older, "older bytes");
         Files.Model.Initialize
           (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
         Files.Model.Clear_Undo (Model);
         Older_Path.Append (To_Unbounded_String (Older));
         Files.Model.Record_Undo
           (Model, Files.Model.Undo_Delete_Created, Older_Path,
            Files.Types.String_Vectors.Empty_Vector, Redoable => False);
         Paths.Append (To_Unbounded_String (Unverifiable));
         Identities.Append (Null_Unbounded_String);
         Revisions.Append (Null_Unbounded_String);
         Recorded := Files.Model.Try_Record_Undo
           (Model, Files.Model.Undo_Delete_Created, Paths,
            Files.Types.String_Vectors.Empty_Vector, Redoable => False,
            Original_Identities => Identities,
            Original_Tree_Revisions => Revisions);
         Assert (not Recorded and then Files.Model.Undo_From_Paths (Model).First_Element = Older,
                 "an identity-free action does not replace an older usable Undo entry");
         declare
            Stale : constant String := Join (Root, "stale-snapshot");
            Saved : constant String := Join (Root, "stale-snapshot-saved");
            Prefix : constant String := Join (Root, "verified-prefix");
            Directory_Path : constant String := Join (Root, "snapshot-directory");
            Incomplete : constant String := Join (Root, "incomplete-redo");
            Candidate, Candidate_Identities, Candidate_Revisions : Files.Types.String_Vectors.Vector;
            Old_Identity, Old_Revision : Files.Types.UString;
            Previous : Files.Model.Undo_Entry;
            Found : Boolean;
         begin
            Write_Binary_File (Stale, "owned bytes");
            Old_Identity := To_Unbounded_String (Files.File_Identities.Token (Stale));
            Ada.Directories.Rename (Stale, Saved);
            Write_Binary_File (Stale, "replacement bytes");
            Candidate.Append (To_Unbounded_String (Stale));
            Candidate_Identities.Append (Old_Identity);
            Candidate_Revisions.Append (Null_Unbounded_String);
            Recorded := Files.Model.Try_Record_Undo
              (Model, Files.Model.Undo_Delete_Created, Candidate,
               Files.Types.String_Vectors.Empty_Vector, Redoable => False,
               Original_Identities => Candidate_Identities,
               Original_Tree_Revisions => Candidate_Revisions);
            Assert (not Recorded and then Files.Model.Undo_From_Paths (Model).First_Element = Older
                    and then File_Has_Bytes (Stale, "replacement bytes"),
                    "a stale supplied identity cannot enter history or displace an older action");

            Write_Binary_File (Prefix, "verified bytes");
            Candidate.Clear;
            Candidate_Identities.Clear;
            Candidate_Revisions.Clear;
            Candidate.Append (To_Unbounded_String (Prefix));
            Candidate_Identities.Append
              (To_Unbounded_String (Files.File_Identities.Token (Prefix)));
            Candidate_Revisions.Append
              (To_Unbounded_String (Files.File_System.Tree_Revision (Prefix)));
            Recorded := Files.Model.Try_Record_Undo
              (Model, Files.Model.Undo_Delete_Created, Candidate,
               Files.Types.String_Vectors.Empty_Vector, Redoable => False,
               Original_Identities => Candidate_Identities,
               Original_Tree_Revisions => Candidate_Revisions);
            Assert (Recorded, "admit the first independently verified batch member");
            Files.Model.Take_Undo (Model, Previous, Found);
            Candidate.Append (To_Unbounded_String (Stale));
            Candidate_Identities.Append (Old_Identity);
            Candidate_Revisions.Append (Null_Unbounded_String);
            Recorded := Files.Model.Try_Record_Undo
              (Model, Files.Model.Undo_Delete_Created, Candidate,
               Files.Types.String_Vectors.Empty_Vector, Redoable => False,
               Original_Identities => Candidate_Identities,
               Original_Tree_Revisions => Candidate_Revisions,
               Retain_Verified_Main => 1);
            Assert
              (Recorded
               and then Natural (Files.Model.Undo_From_Paths (Model).Length) = 1
               and then Files.Model.Undo_From_Paths (Model).First_Element = Prefix,
               "a verified prefix does not admit a newly appended stale snapshot");
            Files.Model.Take_Undo (Model, Previous, Found);

            Candidate.Clear;
            Candidate_Identities.Clear;
            Candidate_Revisions.Clear;
            Ada.Directories.Create_Directory (Directory_Path);
            Write_Binary_File (Join (Directory_Path, "first"), "first");
            Candidate.Append (To_Unbounded_String (Directory_Path));
            Candidate_Identities.Append
              (To_Unbounded_String (Files.File_Identities.Token (Directory_Path)));
            Candidate_Revisions.Append (Null_Unbounded_String);
            Recorded := Files.Model.Try_Record_Undo
              (Model, Files.Model.Undo_Delete_Created, Candidate,
               Files.Types.String_Vectors.Empty_Vector, Redoable => False,
               Original_Identities => Candidate_Identities,
               Original_Tree_Revisions => Candidate_Revisions);
            Assert (not Recorded and then Files.Model.Undo_From_Paths (Model).First_Element = Older,
                    "a created directory without a complete tree revision is not recorded");

            Old_Revision := To_Unbounded_String (Files.File_System.Tree_Revision (Directory_Path));
            Write_Binary_File (Join (Directory_Path, "second"), "second");
            Candidate_Revisions.Replace_Element (Candidate_Revisions.First_Index, Old_Revision);
            Recorded := Files.Model.Try_Record_Undo
              (Model, Files.Model.Undo_Delete_Created, Candidate,
               Files.Types.String_Vectors.Empty_Vector, Redoable => False,
               Original_Identities => Candidate_Identities,
               Original_Tree_Revisions => Candidate_Revisions);
            Assert (not Recorded and then Files.Model.Undo_From_Paths (Model).First_Element = Older,
                    "a stale directory revision cannot enter history");

            Candidate.Clear;
            Candidate_Identities.Clear;
            Candidate_Revisions.Clear;
            Write_Binary_File (Incomplete, "created bytes");
            Candidate.Append (To_Unbounded_String (Incomplete));
            Candidate_Identities.Append
              (To_Unbounded_String (Files.File_Identities.Token (Incomplete)));
            Candidate_Revisions.Append (Null_Unbounded_String);
            Recorded := Files.Model.Try_Record_Undo
              (Model, Files.Model.Undo_Delete_Created, Candidate,
               Files.Types.String_Vectors.Empty_Vector,
               Create_Kind => Files.Model.Create_Copy,
               Original_Identities => Candidate_Identities,
               Original_Tree_Revisions => Candidate_Revisions);
            Assert (not Recorded and then Files.Model.Undo_From_Paths (Model).First_Element = Older,
                    "an action without its required Redo source is not recorded");
         end;
         Paths.Append (To_Unbounded_String (Verifiable));
         Identities.Append (To_Unbounded_String (Files.File_Identities.Token (Verifiable)));
         Revisions.Append
           (To_Unbounded_String (Files.File_System.Tree_Revision (Verifiable)));
         Recorded := Files.Model.Try_Record_Undo
           (Model, Files.Model.Undo_Delete_Created, Paths,
            Files.Types.String_Vectors.Empty_Vector, Redoable => False,
            Original_Identities => Identities,
            Original_Tree_Revisions => Revisions);
         Assert (Recorded
                 and then Natural (Files.Model.Undo_From_Paths (Model).Length) = 1
                 and then Files.Model.Undo_From_Paths (Model).First_Element = Verifiable,
                 "mixed history retains only members with verifiable publication identities");
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Assert (Step.Status = Files.Operations.Operation_Success
                 and then Ada.Directories.Exists (Unverifiable)
                 and then not Ada.Directories.Exists (Verifiable)
                 and then Files.Model.Undo_Available (Model),
                 "filtered Undo removes its verified member and leaves untracked data intact");
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Assert (Step.Status = Files.Operations.Operation_Success
                 and then not Ada.Directories.Exists (Older),
                 "identity filtering leaves earlier usable history reachable");
      end;
      for Mode in Files.File_System.Drop_Import_Mode loop
         for Background in Boolean loop
            Reset_Root;
            Ada.Directories.Create_Directory (Join (Root, "inbox"));
            Write_Binary_File (Join (Join (Root, "inbox"), "a.txt"), "a bytes");
            Write_Binary_File (Join (Join (Root, "inbox"), "b.txt"), "b bytes");
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Clear_Undo (Model);
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
               for Attempt in 1 .. 5_000 loop
                  Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
                  exit when Files.Model.Paste_Execution_Done (Model) = 1;
                  delay 0.001;
               end loop;
               Assert (Files.Model.Paste_Execution_Done (Model) = 1, "the first paste member commits");
               Assert (Hostkit.Fs.Move_No_Replace (A, Saved_A), "retain the first owned entry between batches");
               Write_Binary_File (A, "unrelated a");
               Step := Complete_Operation (Model, Settings, Step);
               Await_View (Model, Settings);
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Failed
                       and then File_Has_Bytes (A, "unrelated a") and then not Ada.Directories.Exists (B),
                       "later paste steps cannot recapture a replacement as an owned entry");
               Mutation := Files.File_System.Delete_Permanently (A);
               Assert (Mutation.Success and then Hostkit.Fs.Move_No_Replace (Saved_A, A),
                       "restore the owned first entry");
               Write_Binary_File (B, "unrelated b");
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success
                       and then not Ada.Directories.Exists (A) and then File_Has_Bytes (B, "unrelated b"),
                       "partial Undo retries preserve unrelated entries at already reversed paths");
            end;
         end loop;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Undo_Entry_Identity;
