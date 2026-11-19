with Ada.Containers.Ordered_Sets;
with Files.Diagnostics;
with Files.Path_Checks;
with Files.Undo_Payloads;
with Files.Model.Support;

package body Files.Model.History is
   use type Files.Undo_History.History_Side;
   use type Files.Undo_History.Undo_Action_Kind;
   use type Files.Undo_History.Undo_Create_Kind;

   use Files.Model.Support;
   use Ada.Strings.Unbounded;

   package UString_Sets is new Ada.Containers.Ordered_Sets
     (Element_Type => UString);

   --  Cap the undo history so a session doing thousands of operations does not
   --  grow it without bound: each entry retains the full source and destination
   --  path lists (and permission/ownership images), so an unbounded stack pins
   --  that data for the life of the window. Past the cap the oldest entry --
   --  least likely to ever be undone -- is dropped; LIFO undo only touches the
   --  newest, so the reachable history is unaffected.
   Max_Undo_Depth : constant := 200;

   function Undo_Entries (Model : Window_Model) return Undo_Entry_Vectors.Vector is (Model.History.Undo_Stack);

   function Redo_Entries (Model : Window_Model) return Undo_Entry_Vectors.Vector is (Model.History.Redo_Stack);

   function Nonempty_Values
     (Values : Files.Types.String_Vectors.Vector) return Boolean is
   begin
      for Value of Values loop
         if Length (Value) = 0 then
            return False;
         end if;
      end loop;
      return True;
   end Nonempty_Values;

   function Unique_Nonempty_Values
     (Values : Files.Types.String_Vectors.Vector) return Boolean
   is
      Seen : UString_Sets.Set;
   begin
      for Value of Values loop
         if Length (Value) = 0 or else Seen.Contains (Value) then
            return False;
         end if;
         Seen.Insert (Value);
      end loop;
      return True;
   end Unique_Nonempty_Values;

   function Valid_Absolute_Path (Value : UString) return Boolean is
     (Files.Path_Checks.Valid_Absolute_Path (To_String (Value)));

   function Absolute_Paths
     (Values : Files.Types.String_Vectors.Vector) return Boolean is
   begin
      for Value of Values loop
         if not Valid_Absolute_Path (Value) then
            return False;
         end if;
      end loop;
      return True;
   end Absolute_Paths;

   function Unique_Absolute_Paths
     (Values : Files.Types.String_Vectors.Vector) return Boolean is
   begin
      return Unique_Nonempty_Values (Values) and then Absolute_Paths (Values);
   end Unique_Absolute_Paths;

   function Completion_Markers_Valid
     (Markers, Allowed : Files.Types.String_Vectors.Vector) return Boolean
   is
      Seen : UString_Sets.Set;
      Allowed_Values : UString_Sets.Set;
   begin
      for Value of Allowed loop
         Allowed_Values.Include (Value);
      end loop;
      for Marker of Markers loop
         if Length (Marker) = 0
           or else not Allowed_Values.Contains (Marker)
           or else Seen.Contains (Marker)
         then
            return False;
         end if;
         Seen.Insert (Marker);
      end loop;
      return True;
   end Completion_Markers_Valid;

   function History_Entry_Usable
     (Action : Undo_Entry; Side : History_Side) return Boolean
   is
      For_Redo : constant Boolean := Side = Redo_Side;
      Main_Count : constant Natural := Natural (Action.Items.Length);
      Restore_Count : constant Natural := Natural (Action.Replaced.Length);

      --  Each item's To, or Forward.
      function Tos return Files.Types.String_Vectors.Vector is
      begin
         return Values : Files.Types.String_Vectors.Vector do
            for Item of Action.Items loop
               Values.Append (Item.To);
            end loop;
         end return;
      end Tos;

      function Forwards return Files.Types.String_Vectors.Vector is
      begin
         return Values : Files.Types.String_Vectors.Vector do
            for Item of Action.Items loop
               Values.Append (Item.Forward);
            end loop;
         end return;
      end Forwards;

      --  No item carries a To, or a Forward.
      function No_To return Boolean is (for all Item of Action.Items => Length (Item.To) = 0);
      function No_Forward return Boolean is (for all Item of Action.Items => Length (Item.Forward) = 0);

      function Payload_Images_Valid
        (Values : Files.Types.String_Vectors.Vector;
         Ownership : Boolean) return Boolean is
      begin
         for Value of Values loop
            if (if Ownership then not Files.Undo_Payloads.Is_Ownership_Text (To_String (Value))
                else not Files.Undo_Payloads.Is_Mode_Text (To_String (Value)))
            then
               return False;
            end if;
         end loop;
         return True;
      end Payload_Images_Valid;

      Kept_Paths, Kept_Identities, Restore_Identities, Restore_Targets : Files.Types.String_Vectors.Vector;
      Restore_Trash : constant Files.Types.String_Vectors.Vector := Replaced_Trash (Action);
      Forward_Markers_Valid : Boolean := False;
      --  Reverse markers name a From path or a kept copy.
      Reverse_Allowed : Files.Types.String_Vectors.Vector := From_Paths (Action);
   begin
      for Copy of Action.Kept loop
         Kept_Paths.Append (Copy.Path);
         Kept_Identities.Append (Copy.Identity);
      end loop;
      for Original of Action.Replaced loop
         Restore_Identities.Append (Original.Identity);
         Restore_Targets.Append (Original.Target);
      end loop;
      Reverse_Allowed.Append_Vector (Kept_Paths);
      if Action.Kind = Undo_None
        or else Main_Count = 0
        or else not Unique_Absolute_Paths (From_Paths (Action))
        or else (not Action.Kept.Is_Empty
          and then (Action.Kind /= Undo_Move
            or else Action.Redoable
            or else not Unique_Absolute_Paths (Kept_Paths)
            or else not Nonempty_Values (Kept_Identities)
            or else not Unique_Nonempty_Values (Reverse_Allowed)))
        or else (for some Item of Action.Items => Length (Item.Identity) = 0)
        or else (For_Redo and then not Action.Redoable)
      then
         return False;
      end if;

      if Restore_Count = 0 then
         if not Action.Restores_Completed.Is_Empty then
            return False;
         end if;
      elsif Action.Redoable
        or else Action.Kind not in Undo_Move | Undo_Delete_Created
        or else not Unique_Absolute_Paths (Restore_Trash)
        or else not Nonempty_Values (Restore_Identities)
        or else not Unique_Absolute_Paths (Restore_Targets)
        or else not Completion_Markers_Valid (Action.Restores_Completed, Restore_Trash)
      then
         return False;
      end if;

      case Action.Kind is
         when Undo_Rename | Undo_Move =>
            if not Unique_Absolute_Paths (Tos)
              or else not No_Forward
              or else Action.Create_Kind /= Create_None
            then
               return False;
            end if;
            Forward_Markers_Valid :=
              Completion_Markers_Valid (Action.Forward_Completed, Tos);

         when Undo_Restore_Trash =>
            if Action.Redoable
              or else not Unique_Absolute_Paths (Tos)
              or else not No_Forward
              or else Action.Create_Kind /= Create_None
              or else Restore_Count /= 0
              or else not Action.Forward_Completed.Is_Empty
            then
               return False;
            end if;
            Forward_Markers_Valid := True;

         when Undo_Delete_Created =>
            if not No_To
              or else (Action.Redoable
                and then (Action.Create_Kind = Create_None
                  or else not Absolute_Paths (Forwards)))
              or else (not Action.Redoable and then not No_Forward)
            then
               return False;
            end if;
            Forward_Markers_Valid :=
              Completion_Markers_Valid (Action.Forward_Completed, From_Paths (Action));

         when Undo_Set_Permissions | Undo_Set_Ownership =>
            if Action.Create_Kind /= Create_None
              or else Restore_Count /= 0
              or else not Payload_Images_Valid (Tos, Action.Kind = Undo_Set_Ownership)
              or else (Action.Redoable
                and then not Payload_Images_Valid (Forwards, Action.Kind = Undo_Set_Ownership))
              or else (not Action.Redoable and then not No_Forward)
              or else not Action.Reverse_Completed.Is_Empty
              or else not Action.Forward_Completed.Is_Empty
            then
               return False;
            end if;
            Forward_Markers_Valid := True;

         when Undo_None =>
            return False;
      end case;

      return Forward_Markers_Valid
        and then Completion_Markers_Valid (Action.Reverse_Completed, Reverse_Allowed)
        and then (not For_Redo or else
          (Action.Reverse_Completed.Is_Empty and then Action.Restores_Completed.Is_Empty))
        and then (For_Redo or else Action.Forward_Completed.Is_Empty)
        and then
          ((Action.Copy_Records.Is_Empty)
           or else (Action.Kind = Undo_Delete_Created
             and then Action.Redoable
             and then Action.Create_Kind = Create_Copy
             and then Files.Copy_Context.Valid (Action.Copy_Records)));
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Model");
         return False;
   end History_Entry_Usable;

   --  The usable entries of Undo and Redo, each with a Sequence: one an
   --  older journal did not carry is given the next of Next.
   procedure Sanitize_History
     (Undo, Redo : Undo_Entry_Vectors.Vector;
      Next : in out Positive;
      Sanitized_Undo, Sanitized_Redo : out Undo_Entry_Vectors.Vector)
   is
      procedure Keep (Action : Undo_Entry; Side : History_Side; Stack : in out Undo_Entry_Vectors.Vector) is
         Kept : Undo_Entry := Action;
      begin
         if History_Entry_Usable (Action, Side) then
            if Kept.Sequence = 0 then
               Kept.Sequence := Next;
            end if;
            Next := Positive'Max (Next, Kept.Sequence + 1);
            Stack.Append (Kept);
         end if;
      end Keep;
   begin
      Sanitized_Undo.Clear;
      Sanitized_Redo.Clear;
      for Action of Undo loop
         Keep (Action, Undo_Side, Sanitized_Undo);
      end loop;
      for Action of Redo loop
         Keep (Action, Redo_Side, Sanitized_Redo);
      end loop;
   end Sanitize_History;

   procedure Restore
     (Model : in out Window_Model;
      Undo, Redo : Undo_Entry_Vectors.Vector;
      State : History_Journal_State := (others => <>))
   is
      package Sequence_Sets is new Ada.Containers.Ordered_Sets (Element_Type => Positive);
      Sanitized_Undo, Sanitized_Redo : Undo_Entry_Vectors.Vector;
      Next : Positive := State.Next_Sequence;
      Held, Listed, Retiring : Sequence_Sets.Set;
      Left_Out, Dropped : Sequence_Vectors.Vector;
   begin
      Sanitize_History (Undo, Redo, Next, Sanitized_Undo, Sanitized_Redo);
      for Action of Sanitized_Undo loop
         Held.Include (Action.Sequence);
      end loop;
      for Action of Sanitized_Redo loop
         Held.Include (Action.Sequence);
      end loop;
      --  The journal's left-out list, pruned to what can still name an entry
      --  the history left out: once each, never one this history holds (it
      --  is journaled again), never one past the Sequences handed out.
      for Sequence of State.Unjournaled loop
         if Sequence < Next and then not Held.Contains (Sequence) and then not Listed.Contains (Sequence) then
            Listed.Include (Sequence);
            Left_Out.Append (Sequence);
         end if;
      end loop;
      --  The entries the journal's cap left out of that list stay named, so
      --  the next journal tells the window to retire them (Merge).
      for Sequence of State.Dropped loop
         if Sequence < Next
           and then not Held.Contains (Sequence)
           and then not Listed.Contains (Sequence)
           and then not Retiring.Contains (Sequence)
         then
            Retiring.Include (Sequence);
            Dropped.Append (Sequence);
         end if;
      end loop;
      Model.History.Undo_Stack := Sanitized_Undo;
      Model.History.Redo_Stack := Sanitized_Redo;
      Model.History.Journal :=
        (Next_Sequence => Next, Unjournaled => Left_Out, Redo_Retired => False, Dropped => Dropped);
      Support.Touch (Model);
   end Restore;

   function Journal_State (Model : Window_Model) return History_Journal_State is (Model.History.Journal);

   function State (Model : Window_Model) return Undo_History_State is (Model.History);

   procedure Merge
     (Model : in out Window_Model;
      Undo, Redo : Undo_Entry_Vectors.Vector;
      State : History_Journal_State)
   is
      package Sequence_Sets is new Ada.Containers.Ordered_Sets (Element_Type => Positive);

      Next : Positive := Positive'Max (State.Next_Sequence, Model.History.Journal.Next_Sequence);
      Journal_Undo, Journal_Redo : Undo_Entry_Vectors.Vector;
      Merged_Undo, Merged_Redo : Undo_Entry_Vectors.Vector;
      Journaled, Unjournaled, Dropped : Sequence_Sets.Set;

      --  Whether the window's Action is still in the history although the
      --  journal does not hold it: the journal lists it as left out.
      function Left_Out (Action : Undo_Entry) return Boolean is
        (Action.Sequence > 0
         and then not Journaled.Contains (Action.Sequence)
         and then Unjournaled.Contains (Action.Sequence));

      --  Whether the window's Action is still in the history although the
      --  journal neither holds nor lists it: the cap on the journal's list
      --  left it out, and no helper released what it preserved.
      function Cap_Dropped (Action : Undo_Entry) return Boolean is
        (Action.Sequence > 0
         and then not Journaled.Contains (Action.Sequence)
         and then not Unjournaled.Contains (Action.Sequence)
         and then Dropped.Contains (Action.Sequence));

      --  The entry of Stack whose Sequence is Sequence, if any.
      function Index_Of (Stack : Undo_Entry_Vectors.Vector; Sequence : Natural) return Natural is
      begin
         for Index in Stack.First_Index .. Stack.Last_Index loop
            if Stack (Index).Sequence = Sequence then
               return Index;
            end if;
         end loop;
         return 0;
      end Index_Of;

      --  Merge one stack: the window's entries in their order, each as the
      --  journal now has it, kept as they are when left out of the journal
      --  (Keep_Left_Out False retires those instead), retired with their
      --  originals released when the journal's cap dropped them, dropped when
      --  the helper retired them; then the journal's entries the window's
      --  stack did not hold (new records, or entries undone or redone onto
      --  this stack).
      procedure Merge_Stack
        (Window, Journal : Undo_Entry_Vectors.Vector;
         Keep_Left_Out   : Boolean;
         Merged          : out Undo_Entry_Vectors.Vector) is
      begin
         Merged.Clear;
         for Action of Window loop
            declare
               Index : constant Natural := Index_Of (Journal, Action.Sequence);
            begin
               if Action.Sequence > 0 and then Index > 0 then
                  Merged.Append (Journal (Index));
               elsif Left_Out (Action) and then Keep_Left_Out then
                  Merged.Append (Action);
               elsif Left_Out (Action)
                 or else (Cap_Dropped (Action) and then not Keep_Left_Out)
               then
                  --  The helper's new record retired the redo stack, and this
                  --  entry, which it never held, with it.
                  for Payload of Replaced_Trash (Action) loop
                     Model.History.Retired_Discards.Append (Payload);
                  end loop;
               elsif Cap_Dropped (Action) then
                  --  Still undoable (or redoable) when the journal had to
                  --  forget it: as an entry past the depth cap, its
                  --  originals go to the system trash, not to deletion.
                  for Payload of Replaced_Trash (Action) loop
                     Model.History.Retired_Releases.Append (Payload);
                  end loop;
               end if;
            end;
         end loop;
         for Action of Journal loop
            if Index_Of (Window, Action.Sequence) = 0 then
               Merged.Append (Action);
            end if;
         end loop;
      end Merge_Stack;
   begin
      Sanitize_History (Undo, Redo, Next, Journal_Undo, Journal_Redo);
      for Action of Journal_Undo loop
         Journaled.Include (Action.Sequence);
      end loop;
      for Action of Journal_Redo loop
         Journaled.Include (Action.Sequence);
      end loop;
      for Sequence of State.Unjournaled loop
         Unjournaled.Include (Sequence);
      end loop;
      for Sequence of State.Dropped loop
         Dropped.Include (Sequence);
      end loop;

      --  An entry the journal neither holds nor lists the helper retired,
      --  payloads and all, unless the journal names it as dropped by its
      --  cap; one it lists stays where the window had it.
      Merge_Stack (Model.History.Undo_Stack, Journal_Undo, Keep_Left_Out => True, Merged => Merged_Undo);
      Merge_Stack
        (Model.History.Redo_Stack, Journal_Redo, Keep_Left_Out => not State.Redo_Retired, Merged => Merged_Redo);

      while Natural (Merged_Undo.Length) > Max_Undo_Depth loop
         --  As Commit_Undo_Record: a dropped entry could still have been
         --  undone, so its originals go to the system trash.
         for Payload of Replaced_Trash (Merged_Undo.First_Element) loop
            Model.History.Retired_Releases.Append (Payload);
         end loop;
         Merged_Undo.Delete_First;
      end loop;

      Model.History.Undo_Stack := Merged_Undo;
      Model.History.Redo_Stack := Merged_Redo;
      Model.History.Journal :=
        (Next_Sequence => Next,
         Unjournaled   => Sequence_Vectors.Empty_Vector,
         Redo_Retired  => Model.History.Journal.Redo_Retired or else State.Redo_Retired,
         Dropped       => Sequence_Vectors.Empty_Vector);
      Model.History.Journal_Dirty := True;
      Support.Touch (Model);
   end Merge;

   procedure Retire_Payloads
     (Pending : in out Files.Types.String_Vectors.Vector;
      Entries : Undo_Entry_Vectors.Vector);

   procedure Retire_Payloads
     (Pending : in out Files.Types.String_Vectors.Vector;
      Entries : Undo_Entry_Vectors.Vector) is
   begin
      for Action of Entries loop
         for Payload of Replaced_Trash (Action) loop
            Pending.Append (Payload);
         end loop;
      end loop;
   end Retire_Payloads;

   procedure Begin_Undo_Record
     (Model : in out Window_Model;
      Kind  : Undo_Action_Kind;
      Items : Undo_Item_Vectors.Vector) is
   begin
      Touch (Model);
      if Kind = Undo_None or else Items.Is_Empty then
         return;
      end if;
      --  A rename or move is recorded once it is done, whether or not it can
      --  be undone: To holds the old path, From the new one.
      if Kind in Undo_Rename | Undo_Move then
         for Item of Items loop
            if Length (Item.To) > 0 then
               Note_Path_Move (Model, To_String (Item.To), To_String (Item.From));
            end if;
         end loop;
      end if;
   end Begin_Undo_Record;

   function Commit_Undo_Record
     (Model  : in out Window_Model;
      Action : Undo_Entry) return Boolean is
      Numbered : Undo_Entry := Action;
   begin
      --  Payloads are queued only once their entry has left both stacks; the
      --  operations layer deletes them when it drains Take_Retired.
      Retire_Payloads (Model.History.Retired_Discards, Model.History.Redo_Stack);
      Model.History.Redo_Stack.Clear;
      --  Redo entries a background helper's journal left out go too.
      Model.History.Journal.Redo_Retired := True;
      --  Undo and Redo availability is drawn and enables commands.
      Touch (Model);
      Model.History.Journal_Dirty := True;
      if Action.Items.Is_Empty then
         --  Nothing to record, but originals a replace preserved must not stay
         --  in hidden stages with no way back: they go to the system trash.
         for Payload of Replaced_Trash (Action) loop
            Model.History.Retired_Releases.Append (Payload);
         end loop;
         return False;
      end if;

      Numbered.Sequence := Model.History.Journal.Next_Sequence;
      Model.History.Journal.Next_Sequence := Model.History.Journal.Next_Sequence + 1;
      Model.History.Undo_Stack.Append (Numbered);
      while Natural (Model.History.Undo_Stack.Length) > Max_Undo_Depth loop
         --  The dropped entry could still have been undone, so the originals it
         --  holds go to the system trash, as on window close, not to deletion.
         for Payload of Replaced_Trash (Model.History.Undo_Stack.First_Element) loop
            Model.History.Retired_Releases.Append (Payload);
         end loop;
         Model.History.Undo_Stack.Delete_First;
      end loop;
      return True;
   end Commit_Undo_Record;

   procedure Take_Retired
     (Model         : in out Window_Model;
      Discarded     : out Files.Types.String_Vectors.Vector;
      Released      : out Files.Types.String_Vectors.Vector;
      Journal_Dirty : out Boolean) is
   begin
      Discarded := Model.History.Retired_Discards;
      Released := Model.History.Retired_Releases;
      Journal_Dirty := Model.History.Journal_Dirty;
      Model.History.Retired_Discards.Clear;
      Model.History.Retired_Releases.Clear;
      Model.History.Journal_Dirty := False;
   end Take_Retired;

   procedure Release
     (Model : in out Window_Model) is
   begin
      Retire_Payloads (Model.History.Retired_Releases, Model.History.Undo_Stack);
      Retire_Payloads (Model.History.Retired_Releases, Model.History.Redo_Stack);
      Model.History.Undo_Stack.Clear;
      Model.History.Redo_Stack.Clear;
      Touch (Model);
   end Release;

   procedure Clear_Undo
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Retire_Payloads (Model.History.Retired_Discards, Model.History.Undo_Stack);
      Retire_Payloads (Model.History.Retired_Discards, Model.History.Redo_Stack);
      Model.History.Undo_Stack.Clear;
      Model.History.Redo_Stack.Clear;
      Model.History.Journal_Dirty := True;
   end Clear_Undo;

   function Undo_Available
     (Model : Window_Model)
      return Boolean is
     (not Model.History.Undo_Stack.Is_Empty);

   function Redo_Available
     (Model : Window_Model)
      return Boolean is
     (not Model.History.Redo_Stack.Is_Empty);

   --  Pop the newest entry of Stack into Action (Found False and a default
   --  entry when it is empty), as Take_Undo and Take_Redo do.
   procedure Take_Newest
     (Stack  : in out Undo_Entry_Vectors.Vector;
      Action : out Undo_Entry;
      Found  : out Boolean) is
   begin
      if Stack.Is_Empty then
         Action := (others => <>);
         Found := False;
         return;
      end if;

      Action := Stack.Last_Element;
      Stack.Delete_Last;
      Found := True;
   end Take_Newest;

   procedure Take_Undo
     (Model  : in out Window_Model;
      Action : out Undo_Entry;
      Found  : out Boolean) is
   begin
      Touch (Model);
      Take_Newest (Model.History.Undo_Stack, Action, Found);
   end Take_Undo;

   procedure Take_Redo
     (Model  : in out Window_Model;
      Action : out Undo_Entry;
      Found  : out Boolean) is
   begin
      Touch (Model);
      Take_Newest (Model.History.Redo_Stack, Action, Found);
   end Take_Redo;

   procedure Push_Redo
     (Model  : in out Window_Model;
      Action : Undo_Entry) is
   begin
      Touch (Model);
      Model.History.Redo_Stack.Append (Action);
      Model.History.Journal_Dirty := True;
   end Push_Redo;

   procedure Push_Undo
     (Model  : in out Window_Model;
      Action : Undo_Entry) is
   begin
      Touch (Model);
      Model.History.Undo_Stack.Append (Action);
      Model.History.Journal_Dirty := True;
   end Push_Undo;

   function Undo_From_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      if Model.History.Undo_Stack.Is_Empty then
         return Files.Types.String_Vectors.Empty_Vector;
      end if;

      return From_Paths (Model.History.Undo_Stack.Last_Element);
   end Undo_From_Paths;

end Files.Model.History;
