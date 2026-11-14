separate (Files_Suite.History)
   --  A journal lists the Sequences of entries it left out, so the window
   --  keeps them on merge. A helper restoring that list keeps only what can
   --  still name a left-out entry: each once, never one it holds itself (that
   --  one is journaled again), never one past the Sequences handed out. A
   --  list still past its cap loses its oldest markers on save -- those
   --  entries are retired on merge -- instead of failing the save a job's
   --  start and checkpoints require.
   procedure Test_Unjournaled_List_Pruned (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Directory : constant String := Join (Root, "history-pruned");
      Window, Helper : Files.Model.Window_Model;
      Empty : Files.Model.Undo_Entry_Vectors.Vector renames Files.Model.Undo_Entry_Vectors.Empty_Vector;
      State : Files.Model.History_Journal_State;
      Restored : constant array (1 .. 6) of Positive := [7, 4, 4, 10, 99, 3];

      --  The window's history: one entry, numbered Sequence.
      function Held_Entry (Sequence : Positive) return Files.Model.Undo_Entry_Vectors.Vector is
         Result : Files.Model.Undo_Entry;
      begin
         Result.Kind := Files.Model.Undo_Delete_Created;
         --  Undo-only: a redoable entry would need its forward paths too.
         Result.Redoable := False;
         Result.From.Append (To_Unbounded_String (Join (Root, "held")));
         Result.Created_Identities.Append (To_Unbounded_String ("1:held"));
         Result.Created_Tree_Revisions.Append (To_Unbounded_String ("rev"));
         Result.Sequence := Sequence;
         return Files.Model.Undo_Entry_Vectors.To_Vector (Result, 1);
      end Held_Entry;

      --  A list's Sequences, "4,7".
      function Image (List : Files.Model.Sequence_Vectors.Vector) return String is
         Result : Unbounded_String;
      begin
         for Sequence of List loop
            if Length (Result) > 0 then
               Append (Result, ",");
            end if;
            Append (Result, Ada.Strings.Fixed.Trim (Positive'Image (Sequence), Ada.Strings.Left));
         end loop;
         return To_String (Result);
      end Image;
   begin
      Reset_Root;
      Ada.Directories.Create_Directory (Directory);

      --  Restored: a duplicate, the held entry's own Sequence and one never
      --  handed out are dropped; the rest keep their order.
      State.Next_Sequence := 11;
      for Sequence of Restored loop
         State.Unjournaled.Append (Sequence);
      end loop;
      Files.Model.Initialize (Helper, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
      Files.Model.History.Set_History (Helper, Held_Entry (10), Empty, State);
      Assert (Natural (Files.Model.History.Undo_History (Helper).Length) = 1, "the held entry is admitted");
      Assert (Image (Files.Model.History.History_State (Helper).Unjournaled) = "7,4,3",
              "the restored list is pruned: " & Image (Files.Model.History.History_State (Helper).Unjournaled));

      --  Past the cap of 800: the save goes through, keeping the newest 800.
      State.Next_Sequence := 2_000;
      State.Unjournaled.Clear;
      for Sequence in 1 .. 900 loop
         State.Unjournaled.Append (Sequence);
      end loop;
      Files.Model.Initialize (Window, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
      Files.Model.History.Set_History (Window, Empty, Empty, State);
      Assert (Natural (Files.Model.History.History_State (Window).Unjournaled.Length) = 900,
              "nothing in range is pruned on restore");
      begin
         Files.History_Journal.Save_To (Directory, Window, Required => True);
      exception
         when Ada.Directories.Use_Error =>
            Assert (False, "a list past its cap does not fail a required save");
      end;
      Files.Model.Initialize (Helper, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
      Assert (Files.History_Journal.Restore (Directory, Helper), "the truncated journal reads back");
      declare
         Kept : constant Files.Model.Sequence_Vectors.Vector := Files.Model.History.History_State (Helper).Unjournaled;
      begin
         Assert (Natural (Kept.Length) = 800, "the list is truncated to its cap:" & Kept.Length'Image);
         Assert (Kept.First_Element = 101 and then Kept.Last_Element = 900,
                 "the oldest markers are the ones dropped: " & Kept.First_Element'Image);
      end;
      Reset_Root;
   end Test_Unjournaled_List_Pruned;
