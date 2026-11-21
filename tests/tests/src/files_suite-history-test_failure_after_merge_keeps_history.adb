with Files.Operation_Results;
with Files.Operation_Commands;
with Files_Suite.Support.Guards;
with Files.Job_Drivers.Operation.Testing;
separate (Files_Suite.History)
   --  A finished operation whose view work fails after its journal was
   --  merged must not merge again: a second merge would drop what was
   --  recorded since the first (an untracked creation), as the journal
   --  never held it.
   procedure Test_Failure_After_Merge_Keeps_History (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : aliased Files.Model.Window_Model;
      Paste    : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operation_Results.Operation_Result;
      Extra    : constant String := Join (Root, "recorded-after-merge");
      Recorded : Natural := 0;
      Has_Extra : Boolean := False;
   begin
      Reset_Root;
      Write_Binary_File (Join (Root, "a.txt"), "a bytes");
      Write_Binary_File (Extra, "made while the job finished");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Operations.Clear_Undo (Model);
      Files.Model.Set_Filter (Model, "a.txt");
      Files.Model.Selection.Select_All_Visible (Model);
      --  A helper job, so the operation finishes through Jobs.Operation.Advance.
      Files.Model.Set_Background_Transfers (Model, True);
      Files.Job_Drivers.Operation.Testing.Fail_After_Merge (Recording => Extra);
      Step := Complete_Operation (Model, Settings, Files.Operation_Commands.Duplicate_Selected (Model, Settings));
      Files.Job_Drivers.Operation.Testing.Stop_Failing_After_Merge;
      pragma Unreferenced (Step);
      for Action of Files.Model.History.Undo_Entries (Model) loop
         Recorded := Recorded + 1;
         for Item of Action.Items loop
            Has_Extra := Has_Extra or else To_String (Item.From) = Extra;
         end loop;
      end loop;
      Assert (Has_Extra, "what was recorded after the merge is still undoable");
      Files_Suite.Support.Assert_Equal (Recorded, 2, "and so is the duplicate the job made");
   exception
      when others =>
         Files.Job_Drivers.Operation.Testing.Stop_Failing_After_Merge;
         raise;
   end Test_Failure_After_Merge_Keeps_History;
