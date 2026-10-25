separate (Files_Suite.Operations)
   procedure Test_Undo_Admits_Verified_Identities (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Step : Files.Operations.Operation_Result;
   begin
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
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Undo_Admits_Verified_Identities;
