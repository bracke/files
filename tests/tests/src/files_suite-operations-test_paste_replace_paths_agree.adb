separate (Files_Suite.Operations)
   --  The in-process paste and the transfer helper run one replace routine:
   --  a replace target that vanished after planning has nothing to preserve
   --  and the paste proceeds, and a move onto its own path is a no-op success.
   procedure Test_Paste_Replace_Paths_Agree (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source   : constant String := Join (Root, "agree-source");
      Dest     : constant String := Join (Root, "agree-vanished");
      Model    : aliased Files.Model.Window_Model;
      Paste : Files_Suite.Support.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;

      procedure Run
        (Actions    : Files.Paste.Resolved_Action_Vectors.Vector;
         Mode       : Files.File_System.Drop_Import_Mode;
         Background : Boolean)
      is
      begin
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Set_Background_Transfers (Model, Background);
         Files.Operations.Begin_Paste_Execution (Model, Actions, Mode);
         Step := Files_Suite.Support.Finish_Paste (Model, Settings);
         Assert (not Files.Model.Pasting.Execution_Is_Active (Model), "the paste finishes its execution");
      end Run;
   begin
      for Background in Boolean loop
         declare
            Where   : constant String := (if Background then "helper" else "foreground");
            Actions : Files.Paste.Resolved_Action_Vectors.Vector;
         begin
            Reset_Root;
            Write_Binary_File (Source, "new");
            --  Planned as a replace, but the target is gone before the paste runs.
            Actions.Append (Files.Paste.Resolved_Action'
                              (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, True));
            Run (Actions, Files.File_System.Drop_Copy, Background);
            Assert (Step.Status /= Files.Operations.Operation_Failed,
                    Where & ": a vanished replace target does not fail the paste");
            Assert (File_Is (Dest, "new"), Where & ": the paste writes the vanished target's path");

            for Replace in Boolean loop
               Actions.Clear;
               Actions.Append (Files.Paste.Resolved_Action'
                                 (To_Unbounded_String (Source), To_Unbounded_String (Source), False, Replace));
               Run (Actions, Files.File_System.Drop_Move, Background);
               Assert (Step.Status /= Files.Operations.Operation_Failed,
                       Where & ": a move onto its own path succeeds");
               Assert (File_Is (Source, "new"), Where & ": a move onto its own path leaves the entry alone");
            end loop;
         end;
      end loop;
   end Test_Paste_Replace_Paths_Agree;
