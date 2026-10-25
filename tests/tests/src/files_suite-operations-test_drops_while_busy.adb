separate (Files_Suite.Operations)
   procedure Test_Drops_While_Busy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Outcome : Files.Controller.Controller_Result;
      Sources : Files.Types.String_Vectors.Vector;
      Finished, Cancelled : Boolean;
   begin
      for Ready in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Directory (Join (Root, "inbox"));
         Write_Binary_File (Join (Root, "original.txt"), "original");
         Write_Binary_File (Join (Join (Root, "inbox"), "incoming.txt"), "incoming");
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Select_Name (Model, "original.txt");
         Files.Model.Set_Background_Transfers (Model, True);
         Step := Files.Operations.Duplicate_Selected (Model, Settings);
         declare
            Job : constant Files.Process_Jobs.Session := Files.Model.Background_Operation (Model);
            Revision : constant Natural := Files.Model.Revision (Model);
         begin
            if Ready then
               for Attempt in Files_Suite.Support.Polling loop
                  Files.Process_Jobs.Poll (Job, Finished, Cancelled);
                  exit when Finished;
               end loop;
               Assert (Finished and then not Cancelled, "the first job committed before a drop arrives");
            end if;
            Sources.Clear;
            Sources.Append (To_Unbounded_String (Join (Join (Root, "inbox"), "incoming.txt")));
            Outcome := Files.Controller.Handle_Drop_Import (Model, Settings, Sources);
            Step := Files.Operations.Begin_Paste (Model, Settings, Sources);
            declare
               Context : constant String :=
                 "controller and direct paste calls preserve the active job and its revision";
            begin
               Files_Suite.Support.Assert_Equal
                 (Outcome.Status, Files.Controller.Controller_Ignored, Context & ": controller drop ignored");
               Files_Suite.Support.Assert_Equal
                 (Step.Status, Files.Operations.Operation_Disabled, Context & ": direct paste disabled");
               Files_Suite.Support.Assert_Equal (Files.Model.Revision (Model), Revision, Context & ": revision");
               Files_Suite.Support.Assert_Equal
                 (Files.Process_Jobs.Path (Files.Model.Background_Operation (Model), ""),
                  Files.Process_Jobs.Path (Job, ""),
                  Context & ": active job");
            end;
         end;
         Step := Complete_Operation (Model, Settings, Step);
         Assert (Files.Model.Undo_Available (Model) and then not Ada.Directories.Exists (Join (Root, "incoming.txt")),
                 "blocked drops leave the original job's committed history intact");
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (not Ada.Directories.Exists (Join (Root, "original (copy).txt"))
                 and then File_Has_Bytes (Join (Root, "original.txt"), "original"),
                 "the original job remains undoable after a blocked drop");
      end loop;
      Write_Binary_File (Join (Root, "incoming.txt"), "existing destination");
      Step := Files.Operations.Begin_Paste (Model, Settings, Sources);
      Assert (Files.Model.Paste_Conflict_Is_Active (Model), "prepare a collision dialog");
      declare
         Revision : constant Natural := Files.Model.Revision (Model);
      begin
         Outcome := Files.Controller.Handle_Drop_Import (Model, Settings, Sources);
         Step := Files.Operations.Begin_Paste (Model, Settings, Sources);
         Files_Suite.Support.Assert_Equal
           (Outcome.Status,
            Files.Controller.Controller_Ignored,
            "a second drop cannot reset an unresolved collision dialog: controller drop ignored");
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operations.Operation_Disabled,
            "a second drop cannot reset an unresolved collision dialog: direct paste disabled");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Revision (Model),
            Revision,
            "a second drop cannot reset an unresolved collision dialog: revision");
         Assert (Files.Model.Paste_Conflict_Is_Active (Model),
                 "a second drop cannot reset an unresolved collision dialog: dialog still open");
      end;
      Files.Model.Clear_Paste_Conflict (Model);
   exception
      when others =>
         Files.Model.Clear_Paste_Conflict (Model);
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         raise;
   end Test_Drops_While_Busy;
