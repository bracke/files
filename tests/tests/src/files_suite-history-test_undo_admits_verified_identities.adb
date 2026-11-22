with Files.Operations.Undo_Recording.Testing;
with Files.Operations.History;
with Files.Operation_Results;
with Files_Suite.Support.Guards;
with Files_Suite.Support.Models;
separate (Files_Suite.History)
   procedure Test_Undo_Admits_Verified_Identities (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : aliased Files.Model.Window_Model;
      Paste : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Step : Files.Operation_Results.Operation_Result;
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
           (Model, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
         Files.Operations.History.Clear_Undo (Model);
         Older_Path.Append (To_Unbounded_String (Older));
         Files.Operations.Undo_Recording.Record_Undo
           (Model, Files.Undo.History.Undo_Delete_Created, Files_Suite.Support.Models.Undo_Items (Older_Path),
            Redoable => False);
         Paths.Append (To_Unbounded_String (Unverifiable));
         Identities.Append (Null_Unbounded_String);
         Revisions.Append (Null_Unbounded_String);
         Recorded := Files.Operations.Undo_Recording.Testing.Try_Record_Undo
           (Model, Files.Undo.History.Undo_Delete_Created,
            Files_Suite.Support.Models.Undo_Items
              (Paths, Identities => Identities, Tree_Revisions => Revisions,
               Provenance => Files.Undo.History.Published),
            Redoable => False);
         Assert (not Recorded and then Files.Model.History.Undo_From_Paths (Model).First_Element = Older,
                 "an identity-free action does not replace an older usable Undo entry");
         declare
            Stale : constant String := Join (Root, "stale-snapshot");
            Saved : constant String := Join (Root, "stale-snapshot-saved");
            Prefix : constant String := Join (Root, "verified-prefix");
            Directory_Path : constant String := Join (Root, "snapshot-directory");
            Incomplete : constant String := Join (Root, "incomplete-redo");
            Candidate, Candidate_Identities, Candidate_Revisions : Files.Types.String_Vectors.Vector;
            Old_Identity, Old_Revision : Files.Types.UString;
            Previous : Files.Undo.History.Undo_Entry;
            Found : Boolean;
         begin
            Write_Binary_File (Stale, "owned bytes");
            Old_Identity := To_Unbounded_String (Files.File_Identities.Token (Stale));
            Ada.Directories.Rename (Stale, Saved);
            Write_Binary_File (Stale, "replacement bytes");
            Candidate.Append (To_Unbounded_String (Stale));
            Candidate_Identities.Append (Old_Identity);
            Candidate_Revisions.Append (Null_Unbounded_String);
            Recorded := Files.Operations.Undo_Recording.Testing.Try_Record_Undo
              (Model, Files.Undo.History.Undo_Delete_Created,
               Files_Suite.Support.Models.Undo_Items
                 (Candidate, Identities => Candidate_Identities, Tree_Revisions => Candidate_Revisions,
                  Provenance => Files.Undo.History.Published),
               Redoable => False);
            Assert
              (not Recorded,
               "a stale supplied identity cannot enter history or displace an older action: not recorded");
            Assert
              (Files.Model.History.Undo_From_Paths (Model).First_Element = Older,
               "a stale supplied identity cannot enter history or displace an older action: older action kept");
            Assert
              (File_Is (Stale, "replacement bytes"),
               "a stale supplied identity cannot enter history or displace an older action: replacement kept");

            Write_Binary_File (Prefix, "verified bytes");
            Candidate.Clear;
            Candidate_Identities.Clear;
            Candidate_Revisions.Clear;
            Candidate.Append (To_Unbounded_String (Prefix));
            Candidate_Identities.Append
              (To_Unbounded_String (Files.File_Identities.Token (Prefix)));
            Candidate_Revisions.Append
              (To_Unbounded_String (Files.File_System.Tree_Revision (Prefix)));
            Recorded := Files.Operations.Undo_Recording.Testing.Try_Record_Undo
              (Model, Files.Undo.History.Undo_Delete_Created,
               Files_Suite.Support.Models.Undo_Items
                 (Candidate, Identities => Candidate_Identities, Tree_Revisions => Candidate_Revisions,
                  Provenance => Files.Undo.History.Published),
               Redoable => False);
            Assert (Recorded, "admit the first independently verified batch member");
            Files.Model.History.Take_Undo (Model, Previous, Found);
            Candidate.Append (To_Unbounded_String (Stale));
            Candidate_Identities.Append (Old_Identity);
            Candidate_Revisions.Append (Null_Unbounded_String);
            declare
               --  The first member was verified when the record above admitted
               --  it; the appended one only published.
               Items : Files.Undo.History.Recorded_Item_Vectors.Vector :=
                 Files_Suite.Support.Models.Undo_Items
                   (Candidate, Identities => Candidate_Identities, Tree_Revisions => Candidate_Revisions,
                    Provenance => Files.Undo.History.Published);
            begin
               Items (1).Provenance := Files.Undo.History.Verified;
               Recorded := Files.Operations.Undo_Recording.Testing.Try_Record_Undo
                 (Model, Files.Undo.History.Undo_Delete_Created, Items, Redoable => False);
            end;
            Assert (Recorded, "a verified member does not admit a newly appended stale snapshot: recorded");
            Files_Suite.Support.Assert_Equal
              (Natural (Files.Model.History.Undo_From_Paths (Model).Length),
               1,
               "a verified member does not admit a newly appended stale snapshot: one path");
            Assert
              (Files.Model.History.Undo_From_Paths (Model).First_Element = Prefix,
               "a verified member does not admit a newly appended stale snapshot: the member kept");
            Files.Model.History.Take_Undo (Model, Previous, Found);

            Candidate.Clear;
            Candidate_Identities.Clear;
            Candidate_Revisions.Clear;
            Ada.Directories.Create_Directory (Directory_Path);
            Write_Binary_File (Join (Directory_Path, "first"), "first");
            Candidate.Append (To_Unbounded_String (Directory_Path));
            Candidate_Identities.Append
              (To_Unbounded_String (Files.File_Identities.Token (Directory_Path)));
            Candidate_Revisions.Append (Null_Unbounded_String);
            Recorded := Files.Operations.Undo_Recording.Testing.Try_Record_Undo
              (Model, Files.Undo.History.Undo_Delete_Created,
               Files_Suite.Support.Models.Undo_Items
                 (Candidate, Identities => Candidate_Identities, Tree_Revisions => Candidate_Revisions,
                  Provenance => Files.Undo.History.Published),
               Redoable => False);
            Assert (not Recorded and then Files.Model.History.Undo_From_Paths (Model).First_Element = Older,
                    "a created directory without a complete tree revision is not recorded");

            Old_Revision := To_Unbounded_String (Files.File_System.Tree_Revision (Directory_Path));
            Write_Binary_File (Join (Directory_Path, "second"), "second");
            Candidate_Revisions.Replace_Element (Candidate_Revisions.First_Index, Old_Revision);
            Recorded := Files.Operations.Undo_Recording.Testing.Try_Record_Undo
              (Model, Files.Undo.History.Undo_Delete_Created,
               Files_Suite.Support.Models.Undo_Items
                 (Candidate, Identities => Candidate_Identities, Tree_Revisions => Candidate_Revisions,
                  Provenance => Files.Undo.History.Published),
               Redoable => False);
            Assert (not Recorded and then Files.Model.History.Undo_From_Paths (Model).First_Element = Older,
                    "a stale directory revision cannot enter history");

            Candidate.Clear;
            Candidate_Identities.Clear;
            Candidate_Revisions.Clear;
            Write_Binary_File (Incomplete, "created bytes");
            Candidate.Append (To_Unbounded_String (Incomplete));
            Candidate_Identities.Append
              (To_Unbounded_String (Files.File_Identities.Token (Incomplete)));
            Candidate_Revisions.Append (Null_Unbounded_String);
            Recorded := Files.Operations.Undo_Recording.Testing.Try_Record_Undo
              (Model, Files.Undo.History.Undo_Delete_Created,
               Files_Suite.Support.Models.Undo_Items
                 (Candidate, Identities => Candidate_Identities, Tree_Revisions => Candidate_Revisions,
                  Provenance => Files.Undo.History.Published),
               Create_Kind => Files.Undo.History.Create_Copy);
            Assert (not Recorded and then Files.Model.History.Undo_From_Paths (Model).First_Element = Older,
                    "an action without its required Redo source is not recorded");
         end;
         Paths.Append (To_Unbounded_String (Verifiable));
         Identities.Append (To_Unbounded_String (Files.File_Identities.Token (Verifiable)));
         Revisions.Append
           (To_Unbounded_String (Files.File_System.Tree_Revision (Verifiable)));
         Recorded := Files.Operations.Undo_Recording.Testing.Try_Record_Undo
           (Model, Files.Undo.History.Undo_Delete_Created,
            Files_Suite.Support.Models.Undo_Items
              (Paths, Identities => Identities, Tree_Revisions => Revisions,
               Provenance => Files.Undo.History.Published),
            Redoable => False);
         Assert (Recorded, "mixed history retains only members with verifiable publication identities: recorded");
         Files_Suite.Support.Assert_Equal
           (Natural (Files.Model.History.Undo_From_Paths (Model).Length),
            1,
            "mixed history retains only members with verifiable publication identities: one path");
         Assert
           (Files.Model.History.Undo_From_Paths (Model).First_Element = Verifiable,
            "mixed history retains only members with verifiable publication identities: verifiable member kept");
         Step := Complete_Operation (Model, Settings, Operation_Commands.Undo_Last (Model, Settings));
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operation_Results.Operation_Success,
            "filtered Undo removes its verified member and leaves untracked data intact: status");
         Assert
           (Ada.Directories.Exists (Unverifiable),
            "filtered Undo removes its verified member and leaves untracked data intact: unverifiable kept");
         Assert
           (not Ada.Directories.Exists (Verifiable),
            "filtered Undo removes its verified member and leaves untracked data intact: verifiable removed");
         Assert
           (Files.Model.History.Undo_Available (Model),
            "filtered Undo removes its verified member and leaves untracked data intact: undo available");
         Step := Complete_Operation (Model, Settings, Operation_Commands.Undo_Last (Model, Settings));
         Assert (Step.Status = Files.Operation_Results.Operation_Success
                 and then not Ada.Directories.Exists (Older),
                 "identity filtering leaves earlier usable history reachable");
      end;
   end Test_Undo_Admits_Verified_Identities;
