with Files.Controller.Testing;
with Files.Operations.History;
with Files.Operations.Paste;
with Files_Suite.Listings;
with Files.Model.Jobs;
with Files.Operation_Results;
with Files_Suite.Support.Guards;
with Files_Suite.Support.Timing;
separate (Files_Suite.Transfer)
   procedure Test_Drops_While_Busy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : aliased Files.Model.Window_Model;
      Paste : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operation_Results.Operation_Result;
      Outcome : Files.Controller.Controller_Result;
      Sources : Files.Types.String_Vectors.Vector;
      Finished, Cancelled : Boolean;
   begin
      for Ready in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Directory (Join (Root, "inbox"));
         Write_Binary_File (Join (Root, "original.txt"), "original");
         Write_Binary_File (Join (Join (Root, "inbox"), "incoming.txt"), "incoming");
         Load := Files_Suite.Listings.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Operations.History.Clear_Undo (Model);
         Select_Name (Model, "original.txt");
         Files.Model.Set_Background_Transfers (Model, True);
         Step := Operation_Commands.Duplicate_Selected (Model, Settings);
         declare
            Job : constant Files.Jobs.Process.Session := Files.Model.Jobs.Background_Operation (Model);
            Revision : constant Natural := Files.Model.Revision (Model);
         begin
            if Ready then
               for Attempt in Files_Suite.Support.Timing.Polling loop
                  Files.Jobs.Process.Poll (Job, Finished, Cancelled);
                  exit when Finished;
               end loop;
               Assert (Finished and then not Cancelled, "the first job committed before a drop arrives");
            end if;
            Sources.Clear;
            Sources.Append (To_Unbounded_String (Join (Join (Root, "inbox"), "incoming.txt")));
            Outcome := Files.Controller.Testing.Handle_Drop_Import (Model, Settings, Sources);
            Step := Files.Operations.Paste.Begin_Paste (Model, Settings, Sources);
            declare
               Context : constant String :=
                 "controller and direct paste calls preserve the active job and its revision";
            begin
               Files_Suite.Support.Assert_Equal
                 (Outcome.Status, Files.Controller.Controller_Ignored, Context & ": controller drop ignored");
               Files_Suite.Support.Assert_Equal
                 (Step.Status, Files.Operation_Results.Operation_Disabled, Context & ": direct paste disabled");
               Files_Suite.Support.Assert_Equal (Files.Model.Revision (Model), Revision, Context & ": revision");
               Files_Suite.Support.Assert_Equal
                 (Files.Jobs.Process.Path (Files.Model.Jobs.Background_Operation (Model), ""),
                  Files.Jobs.Process.Path (Job, ""),
                  Context & ": active job");
            end;
         end;
         Step := Complete_Operation (Model, Settings, Step);
         Assert (Files.Model.History.Undo_Available (Model)
                 and then not Ada.Directories.Exists (Join (Root, "incoming.txt")),
                 "blocked drops leave the original job's committed history intact");
         Step := Complete_Operation (Model, Settings, Operation_Commands.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (not Ada.Directories.Exists (Join (Root, "original (copy).txt"))
                 and then File_Has_Bytes (Join (Root, "original.txt"), "original"),
                 "the original job remains undoable after a blocked drop");
      end loop;
      Write_Binary_File (Join (Root, "incoming.txt"), "existing destination");
      Step := Files.Operations.Paste.Begin_Paste (Model, Settings, Sources);
      Assert (Files.Model.Pasting.Conflict_Is_Active (Model), "prepare a collision dialog");
      declare
         Revision : constant Natural := Files.Model.Revision (Model);
      begin
         Outcome := Files.Controller.Testing.Handle_Drop_Import (Model, Settings, Sources);
         Step := Files.Operations.Paste.Begin_Paste (Model, Settings, Sources);
         Files_Suite.Support.Assert_Equal
           (Outcome.Status,
            Files.Controller.Controller_Ignored,
            "a second drop cannot reset an unresolved collision dialog: controller drop ignored");
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operation_Results.Operation_Disabled,
            "a second drop cannot reset an unresolved collision dialog: direct paste disabled");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Revision (Model),
            Revision,
            "a second drop cannot reset an unresolved collision dialog: revision");
         Assert (Files.Model.Pasting.Conflict_Is_Active (Model),
                 "a second drop cannot reset an unresolved collision dialog: dialog still open");
      end;
      Files.Model.Pasting.Clear_Conflict (Model);
   exception
      when others =>
         Files.Model.Pasting.Clear_Conflict (Model);
         raise;
   end Test_Drops_While_Busy;
