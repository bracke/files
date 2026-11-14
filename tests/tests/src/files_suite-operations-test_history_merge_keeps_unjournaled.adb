separate (Files_Suite.Operations)
   --  A background helper hands its history back through a journal that may
   --  leave entries out (too old, or too large, for its caps). The window
   --  merges it instead of taking it wholesale: what the journal left out
   --  stays where it was, what the helper retired goes, the helper's new
   --  records join on top, and redo entries the helper never saw go when
   --  its new record retired the redo stack. A newest entry too large for
   --  the journal is left out of it rather than failing the save.
   procedure Test_History_Merge_Keeps_Unjournaled (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Directory : constant String := Join (Root, "history-merge");
      --  A field longer than a journal field may be makes its entry unfit.
      Oversized : constant String := [1 .. 33_000 => 'x'];
      Window, Helper : Files.Model.Window_Model;
      Empty : Files.Model.Undo_Entry_Vectors.Vector renames Files.Model.Undo_Entry_Vectors.Empty_Vector;

      function Item (Name : String; Large : Boolean := False; Redoable : Boolean := False)
        return Files.Model.Undo_Entry
      is
         Result : Files.Model.Undo_Entry;
      begin
         Result.Kind := Files.Model.Undo_Delete_Created;
         Result.Redoable := Redoable;
         Result.From.Append (To_Unbounded_String (Join (Root, Name)));
         Result.Created_Identities.Append (To_Unbounded_String ("1:" & Name));
         Result.Created_Tree_Revisions.Append (To_Unbounded_String (if Large then Oversized else "rev"));
         if Redoable then
            Result.Create_Kind := Files.Model.Create_Copy;
            Result.Forward.Append (To_Unbounded_String (Join (Root, Name & "-source")));
         end if;
         return Result;
      end Item;

      function Stack (First : Files.Model.Undo_Entry) return Files.Model.Undo_Entry_Vectors.Vector is
        (Files.Model.Undo_Entry_Vectors.To_Vector (First, 1));

      function Stack (First, Second : Files.Model.Undo_Entry) return Files.Model.Undo_Entry_Vectors.Vector is
         Result : Files.Model.Undo_Entry_Vectors.Vector := Stack (First);
      begin
         Result.Append (Second);
         return Result;
      end Stack;

      --  The names of a stack's entries, oldest first, "a,b".
      function Names (Entries : Files.Model.Undo_Entry_Vectors.Vector) return String is
         Result : Unbounded_String;
      begin
         for Action of Entries loop
            if Length (Result) > 0 then
               Append (Result, ",");
            end if;
            Append (Result, Ada.Directories.Simple_Name (To_String (Action.From.First_Element)));
         end loop;
         return To_String (Result);
      end Names;

      --  A helper: load the window's journal, then record Name unless empty.
      procedure Run_Helper (Name : String) is
      begin
         Files.Model.Initialize (Helper, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
         Assert (Files.History_Journal.Restore (Directory, Helper), "the helper reads the window's journal");
         if Name /= "" then
            Assert (Files.Model.History.Commit_Undo_Record (Helper, Item (Name)), "the helper records " & Name);
         end if;
         Files.History_Journal.Save_To (Directory, Helper, Required => True);
      end Run_Helper;

      procedure Start_Job is
      begin
         Files.History_Journal.Save_To (Directory, Window, Required => True);
      end Start_Job;

      procedure Merge is
      begin
         Assert (Files.History_Journal.Merge (Directory, Window), "the window merges the helper's journal");
      end Merge;
   begin
      Reset_Root;
      Ada.Directories.Create_Directory (Directory);

      --  The oldest entry is too large for the journal: the helper never
      --  sees it, yet the window keeps it under the helper's new record.
      Files.Model.Initialize (Window, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
      Files.Model.History.Set_History (Window, Stack (Item ("a", Large => True), Item ("b")), Empty);
      Start_Job;
      Run_Helper ("c");
      Assert (Names (Files.Model.History.Undo_History (Helper)) = "b,c",
              "the helper holds what the journal gave it: " & Names (Files.Model.History.Undo_History (Helper)));
      Merge;
      Assert (Names (Files.Model.History.Undo_History (Window)) = "a,b,c",
              "the entry left out of the journal stays: " & Names (Files.Model.History.Undo_History (Window)));

      --  What the helper retired goes; what it never saw stays.
      Start_Job;
      Files.Model.Initialize (Helper, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
      Assert (Files.History_Journal.Restore (Directory, Helper), "the second helper reads the journal");
      declare
         Taken : Files.Model.Undo_Entry;
         Found : Boolean;
      begin
         Files.Model.History.Take_Undo (Helper, Taken, Found);
         Assert (Found and then Names (Stack (Taken)) = "c", "the helper consumes its newest entry");
      end;
      Files.History_Journal.Save_To (Directory, Helper, Required => True);
      Merge;
      Assert (Names (Files.Model.History.Undo_History (Window)) = "a,b",
              "the consumed entry goes, the left-out one stays: " & Names (Files.Model.History.Undo_History (Window)));

      --  A newest entry too large for the journal: the save leaves it out
      --  instead of failing, a helper may not undo it, and it stays in place.
      Files.Model.Initialize (Window, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
      Files.Model.History.Set_History (Window, Stack (Item ("b"), Item ("x", Large => True)), Empty);
      Assert (not Files.History_Journal.Journals_Newest (Window, Redo => False),
              "a newest entry too large for the journal is not journaled");
      Start_Job;
      Run_Helper ("d");
      Assert (Names (Files.Model.History.Undo_History (Helper)) = "b,d",
              "only the oversized entry is left out: " & Names (Files.Model.History.Undo_History (Helper)));
      Merge;
      Assert (Names (Files.Model.History.Undo_History (Window)) = "b,x,d",
              "the unjournaled newest entry keeps its place: " & Names (Files.Model.History.Undo_History (Window)));
      Assert (Files.History_Journal.Journals_Newest (Window, Redo => False),
              "with a small newest entry the journal holds it");

      --  Redo: kept while the helper records nothing, retired with the
      --  helper's redo stack when it records something new.
      for Records in Boolean loop
         Files.Model.Initialize (Window, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
         Files.Model.History.Set_History
           (Window, Empty, Stack (Item ("r1", Large => True, Redoable => True), Item ("r2", Redoable => True)));
         Start_Job;
         Run_Helper ((if Records then "e" else ""));
         Merge;
         if Records then
            Assert (Names (Files.Model.History.Redo_History (Window)) = "",
                    "a new record retires every redo entry, also one the helper never saw: "
                    & Names (Files.Model.History.Redo_History (Window)));
            Assert (Names (Files.Model.History.Undo_History (Window)) = "e", "the new record is merged");
         else
            Assert (Names (Files.Model.History.Redo_History (Window)) = "r1,r2",
                    "without a new record the redo entries all stay: "
                    & Names (Files.Model.History.Redo_History (Window)));
         end if;
      end loop;

      --  The same through a real background job's finish
      --  (Files.Operation_Jobs.Advance), not only the merge it calls: a
      --  duplicate run by a helper records its entry on top, and the entry
      --  the journal left out stays under it.
      Reset_Root;
      Write_Binary_File (Join (Root, "item.txt"), "bytes");
      declare
         Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Load       : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (Root, Settings);
         Job_Window : aliased Files.Model.Window_Model;
         --  Ends the job when the block is left, on failure too.
         Paste      : Files_Suite.Support.Paste_Guard (Job_Window'Access);
         pragma Unreferenced (Paste);
         Step       : Files.Operations.Operation_Result;
      begin
         Files.Model.Initialize (Job_Window, Root, Load.Items, Root);
         Files.Model.History.Set_History (Job_Window, Stack (Item ("a", Large => True), Item ("b")), Empty);
         Files.Model.Set_Background_Transfers (Job_Window, True);
         Files.Model.Selection.Select_All_Visible (Job_Window);
         Step := Files.Operations.Duplicate_Selected (Job_Window, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status, Files.Operations.Operation_Success, "the background duplicate starts");
         Assert (Files.Model.Pasting.Execution_Is_Active (Job_Window), "the duplicate runs as a background job");
         Step := Files_Suite.Support.Finish_Paste (Job_Window, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status, Files.Operations.Operation_Success, "the background duplicate completes");
         Assert (Names (Files.Model.History.Undo_History (Job_Window)) = "a,b,item (copy).txt",
                 "the job's finish merges the helper's history, keeping what the journal left out: "
                 & Names (Files.Model.History.Undo_History (Job_Window)));
      end;
      Reset_Root;
   end Test_History_Merge_Keeps_Unjournaled;
