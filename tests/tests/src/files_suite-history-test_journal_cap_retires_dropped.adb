separate (Files_Suite.History)
   --  A journal's list of left-out entries has a cap. An entry whose marker
   --  the cap dropped was neither in the journal nor listed, so the window
   --  merging a helper's journal took it for one the helper had retired: it
   --  left the history silently, and the originals it preserved stayed in
   --  their hidden stage for good. The journal now names the dropped
   --  entries, through the helper too, and the window retires them on
   --  merge, releasing their originals to the system trash. A version 2
   --  journal, without that list, still reads.
   procedure Test_Journal_Cap_Retires_Dropped (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Directory : constant String := Join (Root, "history-dropped");
      --  A field longer than a journal field may be makes its entry unfit.
      Oversized : constant String := [1 .. 33_000 => 'x'];
      Window, Helper : Files.Model.Window_Model;
      Undo : Files.Model.Undo_Entry_Vectors.Vector;
      State : Files.Model.History_Journal_State;

      --  An undo-only entry numbered Sequence; Large ones do not fit the
      --  journal, and Preserving ones hold an original a replace kept.
      function Item (Name : String; Sequence : Positive; Large, Preserving : Boolean) return Files.Model.Undo_Entry is
         Result : Files.Model.Undo_Entry;
      begin
         Result.Kind := Files.Model.Undo_Delete_Created;
         Result.Redoable := False;
         Result.Items.Append
           (Files.Model.Undo_Item'
              (From => To_Unbounded_String (Join (Root, Name)),
               Identity => To_Unbounded_String ("1:" & Name),
               Tree_Revision => To_Unbounded_String (if Large then Oversized else "rev"),
               others => <>));
         if Preserving then
            Result.Replaced.Append
              (Files.Model.Replaced_Original'
                 (Trash => To_Unbounded_String (Join (Root, "stage-" & Name)),
                  Identity => To_Unbounded_String ("2:" & Name),
                  Target => To_Unbounded_String (Join (Root, Name & "-original"))));
         end if;
         Result.Sequence := Sequence;
         return Result;
      end Item;

      --  The names of a stack's entries, oldest first, "a,b".
      function Names (Entries : Files.Model.Undo_Entry_Vectors.Vector) return String is
         Result : Unbounded_String;
      begin
         for Action of Entries loop
            if Length (Result) > 0 then
               Append (Result, ",");
            end if;
            Append (Result, Ada.Directories.Simple_Name (To_String (Action.Items.First_Element.From)));
         end loop;
         return To_String (Result);
      end Names;

      function Holds (List : Files.Types.String_Vectors.Vector; Name : String) return Boolean is
        (List.Contains (To_Unbounded_String (Join (Root, Name))));
   begin
      Reset_Root;
      Ada.Directories.Create_Directory (Directory);

      --  The window's two oldest entries are too large for the journal, and
      --  its left-out list is already full of older markers: the cap drops
      --  the markers of those two.
      Undo.Append (Item ("a", 1, Large => True, Preserving => True));
      Undo.Append (Item ("b", 2, Large => True, Preserving => True));
      Undo.Append (Item ("c", 950, Large => False, Preserving => True));
      State.Next_Sequence := 2_000;
      for Sequence in 3 .. 900 loop
         State.Unjournaled.Append (Sequence);
      end loop;
      Files.Model.Initialize (Window, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
      Files.Model.History.Restore (Window, Undo, Files.Model.Undo_Entry_Vectors.Empty_Vector, State);
      Files.Model.Testing.Save_Journal_To (Directory, Window, Mode => Files.History_Journal.Must_Commit);

      --  The helper carries the dropped markers on into its own journal.
      Files.Model.Initialize (Helper, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
      Assert (Files.Model.Testing.Restore_Journal (Directory, Helper), "the helper reads the window's journal");
      declare
         Helper_State : constant Files.Model.History_Journal_State := Files.Model.History.Journal_State (Helper);
      begin
         Assert (Helper_State.Dropped.Contains (1) and then Helper_State.Dropped.Contains (2),
                 "the journal names the entries its cap dropped");
         Assert (not Helper_State.Unjournaled.Contains (1) and then not Helper_State.Unjournaled.Contains (2),
                 "and does not list them as left out");
      end;
      Assert (Files.Model.History.Commit_Undo_Record (Helper, Item ("d", 1, Large => False, Preserving => False)),
              "the helper records an action");
      Files.Model.Testing.Save_Journal_To (Directory, Helper, Mode => Files.History_Journal.Must_Commit);

      Assert
           (Files.History_Journal."="
              (Files.Model.Testing.Merge_Journal (Directory, Window), Files.History_Journal.Read_Whole),
            "the window merges the helper's journal");
      Assert (Names (Files.Model.History.Undo_Entries (Window)) = "c,d",
              "the dropped entries leave the history: " & Names (Files.Model.History.Undo_Entries (Window)));
      declare
         Discarded, Released : Files.Types.String_Vectors.Vector;
         Dirty : Boolean;
      begin
         Files.Model.History.Take_Retired (Window, Discarded, Released, Dirty);
         Assert (Holds (Released, "stage-a") and then Holds (Released, "stage-b"),
                 "the originals they preserved go to the system trash");
         Assert (not Holds (Discarded, "stage-a") and then not Holds (Discarded, "stage-b"),
                 "rather than being deleted");
         Assert (not Holds (Released, "stage-c") and then not Holds (Discarded, "stage-c"),
                 "the journaled entry keeps its original");
         Assert (Dirty, "the merged history is saved again");
      end;
      Assert (Files.Model.History.Journal_State (Window).Dropped.Is_Empty, "the merge forgets the dropped list");

      --  A version 2 journal, written before the dropped list, still reads.
      declare
         File : Ada.Streams.Stream_IO.File_Type;
      begin
         Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Join (Directory, "history"));
         String'Output (Ada.Streams.Stream_IO.Stream (File), "files-history-2");
         Natural'Output (Ada.Streams.Stream_IO.Stream (File), 5);
         Boolean'Output (Ada.Streams.Stream_IO.Stream (File), False);
         Natural'Output (Ada.Streams.Stream_IO.Stream (File), 1);
         Positive'Output (Ada.Streams.Stream_IO.Stream (File), 3);
         Natural'Output (Ada.Streams.Stream_IO.Stream (File), 0);
         Natural'Output (Ada.Streams.Stream_IO.Stream (File), 0);
         Ada.Streams.Stream_IO.Close (File);
      end;
      Files.Model.Initialize (Helper, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
      Assert (Files.Model.Testing.Restore_Journal (Directory, Helper), "a version 2 journal reads");
      Assert (Files.Model.History.Journal_State (Helper).Unjournaled.Contains (3),
              "with its left-out list");
      Assert (Files.Model.History.Journal_State (Helper).Dropped.Is_Empty, "and no dropped list");
      Reset_Root;
   end Test_Journal_Cap_Retires_Dropped;
