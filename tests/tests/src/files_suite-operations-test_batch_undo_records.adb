with Ada.Real_Time;
with Files.File_System.Testing;
separate (Files_Suite.Operations)
   --  A batch records its Undo entry at once and then at most once a second,
   --  not once per item; a trash batch too, and it undoes completely. A batch
   --  none of whose items can be verified for Undo still succeeds, but says
   --  so ("undo.unavailable"), and does not retry the record on every item.
   procedure Test_Batch_Undo_Records (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings    : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Count       : constant := 12;
      Trash_Home  : constant String := Root & "_batch_undo_xdg";
      Model       : Files.Model.Window_Model;
      Step        : Files.Operations.Operation_Result;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;

      function Name (Index : Positive) return String is
        ("item-" & Files.Types.Natural_Text (Index) & ".txt");

      --  When the batch started: it records once at the start and then at
      --  most once a second, so a slow runner may see one more record per
      --  second the batch took -- never one per item.
      Started : Ada.Real_Time.Time := Ada.Real_Time.Clock;

      function Allowed_Records return Natural is
        (2 + Natural (Ada.Real_Time.To_Duration (Ada.Real_Time."-" (Ada.Real_Time.Clock, Started))));

      procedure Cleanup is
      begin
         Files.Operations.Testing.Count_Undo_Records (False);
         Files.File_System.Testing.Refuse_Creation_Matches (False);
      end Cleanup;

      --  A fresh folder of Count small files, all selected, and no history.
      procedure Prepare is
         Load : Files.File_System.Directory_Load_Result;
      begin
         Reset_Root;
         for Index in 1 .. Count loop
            Write_Binary_File (Join (Root, Name (Index)), "bytes");
         end loop;
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Operations.Clear_Undo (Model);
         Files.Model.Select_All_Visible (Model);
         Files.Operations.Testing.Count_Undo_Records (True);
      end Prepare;

      function Copies_Present return Natural is
         Present : Natural := 0;
      begin
         for Index in 1 .. Count loop
            if Ada.Directories.Exists (Join (Root, "item-" & Files.Types.Natural_Text (Index) & " (copy).txt")) then
               Present := Present + 1;
            end if;
         end loop;
         return Present;
      end Copies_Present;
   begin
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");

      --  Duplicate: twelve fast copies, one entry recorded at most twice.
      Prepare;
      Started := Ada.Real_Time.Clock;
      Step := Files.Operations.Duplicate_Selected (Model, Settings);
      Assert (Step.Status = Files.Operations.Operation_Success, "the duplicate succeeds");
      Files_Suite.Support.Assert_Equal (Copies_Present, Count, "every item is duplicated");
      Assert (Files.Operations.Testing.Undo_Records <= Allowed_Records,
              "the duplicate records its entry at most twice, not once per item:"
              & Natural'Image (Files.Operations.Testing.Undo_Records));
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.Undo_History (Model).Length), 1, "the duplicate is one Undo entry");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.Undo_From_Paths (Model).Length), Count, "the entry covers every copy");
      Assert (Files.Model.Last_Error_Key (Model) = "", "a recorded Undo shows no notice");
      Step := Files.Operations.Undo_Last (Model, Settings);
      Assert (Step.Status = Files.Operations.Operation_Success, "the duplicate undoes");
      Files_Suite.Support.Assert_Equal (Copies_Present, 0, "Undo removes every copy");

      --  Trash: the same throttle, and one Undo brings every item back.
      Prepare;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Started := Ada.Real_Time.Clock;
      Step := Files.Operations.Delete_Selected (Model, Settings);
      Assert (Step.Status = Files.Operations.Operation_Success, "the trash batch succeeds");
      for Index in 1 .. Count loop
         Assert (not Ada.Directories.Exists (Join (Root, Name (Index))), "item" & Index'Image & " is trashed");
      end loop;
      Assert (Files.Operations.Testing.Undo_Records <= Allowed_Records,
              "the trash batch records its entry at most twice:"
              & Natural'Image (Files.Operations.Testing.Undo_Records));
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.Undo_History (Model).Length), 1, "the trash batch is one Undo entry");
      Step := Files.Operations.Undo_Last (Model, Settings);
      Assert (Step.Status = Files.Operations.Operation_Success, "the trash batch undoes");
      for Index in 1 .. Count loop
         Assert (File_Has_Bytes (Join (Root, Name (Index)), "bytes"), "item" & Index'Image & " is restored");
      end loop;
      Assert (not Files.Model.Undo_Available (Model), "one Undo restored the whole batch");
      Project_Tools.Files.Delete_Tree (Trash_Home);

      --  No copy can be verified: the duplicate stands, without Undo, and
      --  says so; the refused record is not retried on every item.
      Prepare;
      Files.File_System.Testing.Refuse_Creation_Matches (True);
      Started := Ada.Real_Time.Clock;
      Step := Files.Operations.Duplicate_Selected (Model, Settings);
      Assert (Step.Status = Files.Operations.Operation_Success, "an unverifiable duplicate still succeeds");
      Files_Suite.Support.Assert_Equal (Copies_Present, Count, "every unverifiable copy stays");
      Assert (not Files.Model.Undo_Available (Model), "no Undo is recorded for unverifiable copies");
      Assert (Files.Model.Last_Error_Key (Model) = "undo.unavailable",
              "the missing Undo is reported, not passed over: " & Files.Model.Last_Error_Key (Model));
      Assert (Files.Operations.Testing.Undo_Records <= Allowed_Records,
              "a refused record is retried at most once more:"
              & Natural'Image (Files.Operations.Testing.Undo_Records));
      Cleanup;
      Reset_Root;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Batch_Undo_Records;
