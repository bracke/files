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

   function Undo_Entries (Model : Window_Model) return Files.Undo_History.Undo_Entry_Vectors.Vector is
     (Model.History.Undo_Stack);

   function Redo_Entries (Model : Window_Model) return Files.Undo_History.Undo_Entry_Vectors.Vector is
     (Model.History.Redo_Stack);

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

   --  The validators History_Entry_Usable is made of. Each reads one part
   --  of an entry read back from the journal; Parts are the vectors several
   --  of them share, built once.
   type Entry_Parts is record
      Tos, Forwards                         : Files.Types.String_Vectors.Vector;
      Kept_Paths, Kept_Identities           : Files.Types.String_Vectors.Vector;
      Restore_Identities, Restore_Targets   : Files.Types.String_Vectors.Vector;
      Restore_Trash                         : Files.Types.String_Vectors.Vector;
      --  Reverse markers name a From path or a kept copy.
      Reverse_Allowed                       : Files.Types.String_Vectors.Vector;
   end record;

   function Parts_Of (Action : Files.Undo_History.Undo_Entry) return Entry_Parts is
   begin
      return Parts : Entry_Parts do
         for Item of Action.Items loop
            Parts.Tos.Append (Item.To);
            Parts.Forwards.Append (Item.Forward);
         end loop;
         for Copy of Action.Kept loop
            Parts.Kept_Paths.Append (Copy.Path);
            Parts.Kept_Identities.Append (Copy.Identity);
         end loop;
         for Original of Action.Replaced loop
            Parts.Restore_Identities.Append (Original.Identity);
            Parts.Restore_Targets.Append (Original.Target);
         end loop;
         Parts.Restore_Trash := Files.Undo_History.Replaced_Trash (Action);
         Parts.Reverse_Allowed := Files.Undo_History.From_Paths (Action);
         Parts.Reverse_Allowed.Append_Vector (Parts.Kept_Paths);
      end return;
   end Parts_Of;

   --  No item carries a To, or a Forward.
   function No_To (Action : Files.Undo_History.Undo_Entry) return Boolean is
     (for all Item of Action.Items => Length (Item.To) = 0);
   function No_Forward (Action : Files.Undo_History.Undo_Entry) return Boolean is
     (for all Item of Action.Items => Length (Item.Forward) = 0);

   --  Every value is a permission (or, for Ownership, an owner) payload.
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

   --  What every kind needs: items with unique absolute From paths and an
   --  identity each, kept copies only on an undo-only move, and a redo only
   --  of what can be redone.
   function Shape_Valid
     (Action : Files.Undo_History.Undo_Entry; Parts : Entry_Parts; For_Redo : Boolean) return Boolean is
     (Action.Kind /= Files.Undo_History.Undo_None
      and then not Action.Items.Is_Empty
      and then Unique_Absolute_Paths (Files.Undo_History.From_Paths (Action))
      and then (Action.Kept.Is_Empty
        or else (Action.Kind = Files.Undo_History.Undo_Move
          and then not Action.Redoable
          and then Unique_Absolute_Paths (Parts.Kept_Paths)
          and then Nonempty_Values (Parts.Kept_Identities)
          and then Unique_Nonempty_Values (Parts.Reverse_Allowed)))
      and then (for all Item of Action.Items => Length (Item.Identity) /= 0)
      and then (not For_Redo or else Action.Redoable));

   --  Replaced originals to restore: only on an undo-only move or
   --  delete-created, each with a unique trash path, identity and target,
   --  and completion markers naming their trash paths.
   function Restores_Valid (Action : Files.Undo_History.Undo_Entry; Parts : Entry_Parts) return Boolean is
     (if Action.Replaced.Is_Empty then Action.Restores_Completed.Is_Empty
      else not Action.Redoable
        and then Action.Kind in Files.Undo_History.Undo_Move | Files.Undo_History.Undo_Delete_Created
        and then Unique_Absolute_Paths (Parts.Restore_Trash)
        and then Nonempty_Values (Parts.Restore_Identities)
        and then Unique_Absolute_Paths (Parts.Restore_Targets)
        and then Completion_Markers_Valid (Action.Restores_Completed, Parts.Restore_Trash));

   --  A rename or move: unique absolute To paths, no Forward, no create;
   --  forward markers name a To path.
   function Move_Valid (Action : Files.Undo_History.Undo_Entry; Parts : Entry_Parts) return Boolean is
     (Unique_Absolute_Paths (Parts.Tos)
      and then No_Forward (Action)
      and then Action.Create_Kind = Files.Undo_History.Create_None
      and then Completion_Markers_Valid (Action.Forward_Completed, Parts.Tos));

   --  A restore from the trash: undo-only, like a move but with nothing
   --  replaced and no forward markers.
   function Restore_Trash_Valid (Action : Files.Undo_History.Undo_Entry; Parts : Entry_Parts) return Boolean is
     (not Action.Redoable
      and then Unique_Absolute_Paths (Parts.Tos)
      and then No_Forward (Action)
      and then Action.Create_Kind = Files.Undo_History.Create_None
      and then Action.Replaced.Is_Empty
      and then Action.Forward_Completed.Is_Empty);

   --  A delete of what was created: no To; a redoable one says what it
   --  created and where (Forward); forward markers name a From path.
   function Delete_Created_Valid (Action : Files.Undo_History.Undo_Entry; Parts : Entry_Parts) return Boolean is
     (No_To (Action)
      and then (if Action.Redoable
                then Action.Create_Kind /= Files.Undo_History.Create_None and then Absolute_Paths (Parts.Forwards)
                else No_Forward (Action))
      and then Completion_Markers_Valid (Action.Forward_Completed, Files.Undo_History.From_Paths (Action)));

   --  A permission or ownership change: payload images to go back to (and
   --  forward to, when redoable), no create, nothing replaced, no markers.
   function Payload_Change_Valid (Action : Files.Undo_History.Undo_Entry; Parts : Entry_Parts) return Boolean is
      Ownership : constant Boolean := Action.Kind = Files.Undo_History.Undo_Set_Ownership;
   begin
      return Action.Create_Kind = Files.Undo_History.Create_None
        and then Action.Replaced.Is_Empty
        and then Payload_Images_Valid (Parts.Tos, Ownership)
        and then (if Action.Redoable then Payload_Images_Valid (Parts.Forwards, Ownership)
                  else No_Forward (Action))
        and then Action.Reverse_Completed.Is_Empty
        and then Action.Forward_Completed.Is_Empty;
   end Payload_Change_Valid;

   --  What the kind itself requires, forward completion markers included.
   function Kind_Valid (Action : Files.Undo_History.Undo_Entry; Parts : Entry_Parts) return Boolean is
     (case Action.Kind is
         when Files.Undo_History.Undo_Rename | Files.Undo_History.Undo_Move => Move_Valid (Action, Parts),
         when Files.Undo_History.Undo_Restore_Trash => Restore_Trash_Valid (Action, Parts),
         when Files.Undo_History.Undo_Delete_Created => Delete_Created_Valid (Action, Parts),
         when Files.Undo_History.Undo_Set_Permissions
            | Files.Undo_History.Undo_Set_Ownership => Payload_Change_Valid (Action, Parts),
         when Files.Undo_History.Undo_None => False);

   --  Where a half-done step stands: reverse markers name a From path or a
   --  kept copy; a redo has no reverse or restore step done, an undo no
   --  forward step; copy records only on a redoable copy-create delete.
   function Progress_Valid
     (Action : Files.Undo_History.Undo_Entry; Parts : Entry_Parts; For_Redo : Boolean) return Boolean is
     (Completion_Markers_Valid (Action.Reverse_Completed, Parts.Reverse_Allowed)
      and then (not For_Redo or else
        (Action.Reverse_Completed.Is_Empty and then Action.Restores_Completed.Is_Empty))
      and then (For_Redo or else Action.Forward_Completed.Is_Empty)
      and then
        (Action.Copy_Records.Is_Empty
         or else (Action.Kind = Files.Undo_History.Undo_Delete_Created
           and then Action.Redoable
           and then Action.Create_Kind = Files.Undo_History.Create_Copy
           and then Files.Copy_Context.Valid (Action.Copy_Records))));

   function History_Entry_Usable
     (Action : Files.Undo_History.Undo_Entry; Side : Files.Undo_History.History_Side) return Boolean
   is
      For_Redo : constant Boolean := Side = Files.Undo_History.Redo_Side;
      Parts    : constant Entry_Parts := Parts_Of (Action);
   begin
      return Shape_Valid (Action, Parts, For_Redo)
        and then Restores_Valid (Action, Parts)
        and then Kind_Valid (Action, Parts)
        and then Progress_Valid (Action, Parts, For_Redo);
   exception
      --  The checks are pure reads of what the journal held; a value out of
      --  any range they assume (a corrupt record) makes the entry unusable.
      when Malformed : Constraint_Error =>
         Files.Diagnostics.Note (Malformed, "Files.Model");
         return False;
   end History_Entry_Usable;

   --  The usable entries of Undo and Redo, each with a Sequence: one an
   --  older journal did not carry is given the next of Next.
   procedure Sanitize_History
     (Undo, Redo : Files.Undo_History.Undo_Entry_Vectors.Vector;
      Next : in out Positive;
      Sanitized_Undo, Sanitized_Redo : out Files.Undo_History.Undo_Entry_Vectors.Vector)
   is
      procedure Keep
        (Action : Files.Undo_History.Undo_Entry;
         Side   : Files.Undo_History.History_Side;
         Stack  : in out Files.Undo_History.Undo_Entry_Vectors.Vector) is
         Kept : Files.Undo_History.Undo_Entry := Action;
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
         Keep (Action, Files.Undo_History.Undo_Side, Sanitized_Undo);
      end loop;
      for Action of Redo loop
         Keep (Action, Files.Undo_History.Redo_Side, Sanitized_Redo);
      end loop;
   end Sanitize_History;

   procedure Restore
     (Model : in out Window_Model;
      Undo, Redo : Files.Undo_History.Undo_Entry_Vectors.Vector;
      State : Files.Undo_History.History_Journal_State := (others => <>))
   is
      package Sequence_Sets is new Ada.Containers.Ordered_Sets (Element_Type => Positive);
      Sanitized_Undo, Sanitized_Redo : Files.Undo_History.Undo_Entry_Vectors.Vector;
      Next : Positive := State.Next_Sequence;
      Held, Listed, Retiring : Sequence_Sets.Set;
      Left_Out, Dropped : Files.Undo_History.Sequence_Vectors.Vector;
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

   function Journal_State (Model : Window_Model) return Files.Undo_History.History_Journal_State is
     (Model.History.Journal);

   function State (Model : Window_Model) return Files.Undo_History.Undo_History_State is (Model.History);

   procedure Merge
     (Model : in out Window_Model;
      Undo, Redo : Files.Undo_History.Undo_Entry_Vectors.Vector;
      State : Files.Undo_History.History_Journal_State)
   is
      package Sequence_Sets is new Ada.Containers.Ordered_Sets (Element_Type => Positive);

      Next : Positive := Positive'Max (State.Next_Sequence, Model.History.Journal.Next_Sequence);
      Journal_Undo, Journal_Redo : Files.Undo_History.Undo_Entry_Vectors.Vector;
      Merged_Undo, Merged_Redo : Files.Undo_History.Undo_Entry_Vectors.Vector;
      Journaled, Unjournaled, Dropped : Sequence_Sets.Set;

      --  Whether the window's Action is still in the history although the
      --  journal does not hold it: the journal lists it as left out.
      function Left_Out (Action : Files.Undo_History.Undo_Entry) return Boolean is
        (Action.Sequence > 0
         and then not Journaled.Contains (Action.Sequence)
         and then Unjournaled.Contains (Action.Sequence));

      --  Whether the window's Action is still in the history although the
      --  journal neither holds nor lists it: the cap on the journal's list
      --  left it out, and no helper released what it preserved.
      function Cap_Dropped (Action : Files.Undo_History.Undo_Entry) return Boolean is
        (Action.Sequence > 0
         and then not Journaled.Contains (Action.Sequence)
         and then not Unjournaled.Contains (Action.Sequence)
         and then Dropped.Contains (Action.Sequence));

      --  The entry of Stack whose Sequence is Sequence, if any.
      function Index_Of (Stack : Files.Undo_History.Undo_Entry_Vectors.Vector; Sequence : Natural) return Natural is
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
        (Window, Journal : Files.Undo_History.Undo_Entry_Vectors.Vector;
         Keep_Left_Out   : Boolean;
         Merged          : out Files.Undo_History.Undo_Entry_Vectors.Vector) is
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
                  for Payload of Files.Undo_History.Replaced_Trash (Action) loop
                     Model.History.Retired_Discards.Append (Payload);
                  end loop;
               elsif Cap_Dropped (Action) then
                  --  Still undoable (or redoable) when the journal had to
                  --  forget it: as an entry past the depth cap, its
                  --  originals go to the system trash, not to deletion.
                  for Payload of Files.Undo_History.Replaced_Trash (Action) loop
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
         for Payload of Files.Undo_History.Replaced_Trash (Merged_Undo.First_Element) loop
            Model.History.Retired_Releases.Append (Payload);
         end loop;
         Merged_Undo.Delete_First;
      end loop;

      Model.History.Undo_Stack := Merged_Undo;
      Model.History.Redo_Stack := Merged_Redo;
      Model.History.Journal :=
        (Next_Sequence => Next,
         Unjournaled   => Files.Undo_History.Sequence_Vectors.Empty_Vector,
         Redo_Retired  => Model.History.Journal.Redo_Retired or else State.Redo_Retired,
         Dropped       => Files.Undo_History.Sequence_Vectors.Empty_Vector);
      Model.History.Journal_Dirty := True;
      Support.Touch (Model);
   end Merge;

   procedure Retire_Payloads
     (Pending : in out Files.Types.String_Vectors.Vector;
      Entries : Files.Undo_History.Undo_Entry_Vectors.Vector);

   procedure Retire_Payloads
     (Pending : in out Files.Types.String_Vectors.Vector;
      Entries : Files.Undo_History.Undo_Entry_Vectors.Vector) is
   begin
      for Action of Entries loop
         for Payload of Files.Undo_History.Replaced_Trash (Action) loop
            Pending.Append (Payload);
         end loop;
      end loop;
   end Retire_Payloads;

   procedure Begin_Undo_Record
     (Model : in out Window_Model;
      Kind  : Files.Undo_History.Undo_Action_Kind;
      Items : Files.Undo_History.Undo_Item_Vectors.Vector) is
   begin
      Touch (Model);
      if Kind = Files.Undo_History.Undo_None or else Items.Is_Empty then
         return;
      end if;
      --  A rename or move is recorded once it is done, whether or not it can
      --  be undone: To holds the old path, From the new one.
      if Kind in Files.Undo_History.Undo_Rename | Files.Undo_History.Undo_Move then
         for Item of Items loop
            if Length (Item.To) > 0 then
               Note_Path_Move (Model, To_String (Item.To), To_String (Item.From));
            end if;
         end loop;
      end if;
   end Begin_Undo_Record;

   function Commit_Undo_Record
     (Model  : in out Window_Model;
      Action : Files.Undo_History.Undo_Entry) return Boolean is
      Numbered : Files.Undo_History.Undo_Entry := Action;
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
         for Payload of Files.Undo_History.Replaced_Trash (Action) loop
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
         for Payload of Files.Undo_History.Replaced_Trash (Model.History.Undo_Stack.First_Element) loop
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
     (Stack  : in out Files.Undo_History.Undo_Entry_Vectors.Vector;
      Action : out Files.Undo_History.Undo_Entry;
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
      Action : out Files.Undo_History.Undo_Entry;
      Found  : out Boolean) is
   begin
      Touch (Model);
      Take_Newest (Model.History.Undo_Stack, Action, Found);
   end Take_Undo;

   procedure Take_Redo
     (Model  : in out Window_Model;
      Action : out Files.Undo_History.Undo_Entry;
      Found  : out Boolean) is
   begin
      Touch (Model);
      Take_Newest (Model.History.Redo_Stack, Action, Found);
   end Take_Redo;

   function Drop_Undone
     (Model    : in out Window_Model;
      Sequence : Natural)
      return Boolean is
   begin
      if Sequence = 0
        or else Model.History.Undo_Stack.Is_Empty
        or else Model.History.Undo_Stack.Last_Element.Sequence /= Sequence
      then
         return False;
      end if;
      Touch (Model);
      Model.History.Undo_Stack.Delete_Last;
      --  The step the helper would have pushed for Redo is lost, so what the
      --  redo stack holds would be offered out of order: it is retired as a
      --  newly recorded action retires it (payloads for Take_Retired).
      Retire_Payloads (Model.History.Retired_Discards, Model.History.Redo_Stack);
      Model.History.Redo_Stack.Clear;
      Model.History.Journal.Redo_Retired := True;
      Model.History.Journal_Dirty := True;
      return True;
   end Drop_Undone;

   procedure Push_Redo
     (Model  : in out Window_Model;
      Action : Files.Undo_History.Undo_Entry) is
   begin
      Touch (Model);
      Model.History.Redo_Stack.Append (Action);
      Model.History.Journal_Dirty := True;
   end Push_Redo;

   procedure Push_Undo
     (Model  : in out Window_Model;
      Action : Files.Undo_History.Undo_Entry) is
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

      return Files.Undo_History.From_Paths (Model.History.Undo_Stack.Last_Element);
   end Undo_From_Paths;

end Files.Model.History;
