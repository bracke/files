with Files.Diagnostics;
with Ada.Real_Time;
with Ada.Containers;
with Ada.Containers.Ordered_Sets;
with Ada.Streams;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings.Unbounded;
with Files.Bounded_Streams;
with Files.Durable_Writes;
with Files.Job_Context;
with Files.Lease_Streams;
with Files.Types;
with Files.Fs_Primitives;
with Hostkit.Fs;
with Hostkit.Lease_Files;
with Files.Path_Checks;

package body Files.History_Journal is
   use Ada.Strings.Unbounded;
   use type Ada.Containers.Count_Type;
   use type Ada.Directories.File_Kind;
   use type Hostkit.Lease_Files.Open_Outcome;

   --  Version 2 adds, before the stacks, the next entry Sequence, whether
   --  redo was retired and the Sequences left out; and to each entry its
   --  kept copies and Sequence. Version 3 adds, after the Sequences left
   --  out, those the cap on that list dropped. Version 1 and 2 journals
   --  still read, without what they lack.
   Journal_Header : constant String := "files-history-3";
   Version_2_Header : constant String := "files-history-2";
   Version_1_Header : constant String := "files-history-1";
   Max_Journal_Bytes : constant := 64 * 1024 * 1024;
   Max_History_Entries : constant := 200;
   Max_Vector_Fields : constant := 1_000_000;
   Max_Journal_Fields : constant := 2_000_000;
   Max_Field_Length : constant := 32 * 1024;
   Max_Unjournaled : constant := 4 * Max_History_Entries;

   function Valid_Directory (Directory : String) return Boolean is
     (Files.Path_Checks.Valid_Absolute_Path (Directory, Max_Field_Length));

   --  The bytes the journal is reckoned to take, as written (Write_Entry)
   --  and as estimated (Add_Cost): the one count both keep.
   subtype Byte_Count is Long_Long_Integer;

   procedure Write_Vector
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value  : Files.Types.String_Vectors.Vector;
      Total  : in out Byte_Count;
      Fields : in out Natural)
   is
   begin
      if Value.Length > Ada.Containers.Count_Type (Max_Vector_Fields)
        or else Value.Length > Ada.Containers.Count_Type (Max_Journal_Fields - Fields)
        or else Total > Max_Journal_Bytes - 16
      then
         raise Ada.Directories.Use_Error;
      end if;
      Total := Total + 16;
      Fields := Fields + Natural (Value.Length);
      Natural'Output (Stream, Natural (Value.Length));
      for Item of Value loop
         if Length (Item) > Max_Field_Length
           or else Byte_Count (Length (Item)) + 16 > Max_Journal_Bytes - Total
         then
            raise Ada.Directories.Use_Error;
         end if;
         Total := Total + Byte_Count (Length (Item)) + 16;
         String'Output (Stream, To_String (Item));
      end loop;
   end Write_Vector;

   function Read_Vector
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Fields : in out Natural)
      return Files.Types.String_Vectors.Vector
   is
      Count : constant Natural := Natural'Input (Stream);
      Result : Files.Types.String_Vectors.Vector;
   begin
      if Count > Max_Vector_Fields or else Count > Max_Journal_Fields - Fields then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Fields := Fields + Count;
      Result.Reserve_Capacity (Ada.Containers.Count_Type (Count));
      for Index in 1 .. Count loop
         Result.Append
           (To_Unbounded_String
              (Files.Bounded_Streams.Input_String
                 (Stream, Max_Field_Length)));
      end loop;
      return Result;
   end Read_Vector;

   --  The vector fields of a journal entry, in the order the journal holds
   --  them: the one list Write_Entry, Read_Entry and Add_Cost go through.
   --  Each is a column of the entry's records (Files.Undo_History.Undo_Item and the
   --  rest), written whole; the kept-copy columns came with version 2.
   type Vector_Field is
     (From_Field, To_Field, Forward_Field,
      Restore_Trash_Field, Restore_Identities_Field, Restore_Targets_Field,
      Reverse_Completed_Field, Restores_Completed_Field, Forward_Completed_Field, Copy_Records_Field,
      Created_Identities_Field, Created_Tree_Revisions_Field,
      Kept_Copies_Field, Kept_Copy_Identities_Field, Kept_Copy_Tree_Revisions_Field);

   --  Before the create kind and the redoable flag; after them; and of those
   --  after, the ones a version 1 journal has.
   subtype Leading_Field is Vector_Field range From_Field .. Forward_Field;
   subtype Trailing_Field is Vector_Field range Restore_Trash_Field .. Kept_Copy_Tree_Revisions_Field;
   subtype Version_1_Field is Vector_Field range Restore_Trash_Field .. Created_Tree_Revisions_Field;

   type Field_Columns is array (Vector_Field) of Files.Types.String_Vectors.Vector;

   --  Value's column Which. A To or Forward no item carries is written
   --  empty, as the action has none.
   function Column
     (Value : Files.Undo_History.Undo_Entry;
      Which : Vector_Field) return Files.Types.String_Vectors.Vector
   is
      Result : Files.Types.String_Vectors.Vector;
   begin
      case Which is
         when From_Field | To_Field | Forward_Field | Created_Identities_Field | Created_Tree_Revisions_Field =>
            for Item of Value.Items loop
               Result.Append
                 ((case Which is
                     when From_Field               => Item.From,
                     when To_Field                 => Item.To,
                     when Forward_Field            => Item.Forward,
                     when Created_Identities_Field => Item.Identity,
                     when others                   => Item.Tree_Revision));
            end loop;
            if Which in To_Field | Forward_Field and then (for all Item of Result => Length (Item) = 0) then
               Result.Clear;
            end if;
         when Restore_Trash_Field | Restore_Identities_Field | Restore_Targets_Field =>
            for Original of Value.Replaced loop
               Result.Append
                 ((case Which is
                     when Restore_Trash_Field      => Original.Trash,
                     when Restore_Identities_Field => Original.Identity,
                     when others                   => Original.Target));
            end loop;
         when Kept_Copies_Field | Kept_Copy_Identities_Field | Kept_Copy_Tree_Revisions_Field =>
            for Copy of Value.Kept loop
               Result.Append
                 ((case Which is
                     when Kept_Copies_Field          => Copy.Path,
                     when Kept_Copy_Identities_Field => Copy.Identity,
                     when others                     => Copy.Tree_Revision));
            end loop;
         when Reverse_Completed_Field  => Result := Value.Reverse_Completed;
         when Restores_Completed_Field => Result := Value.Restores_Completed;
         when Forward_Completed_Field  => Result := Value.Forward_Completed;
         when Copy_Records_Field       => Result := Value.Copy_Records;
      end case;
      return Result;
   end Column;

   --  Put an entry's records together from its columns. Each record is one
   --  of its leading column's (From, Restore_Trash, Kept_Copies); a column
   --  beside it must be as long, or empty where the action may have none (To
   --  and Forward). One that is not was never written by Write_Entry, so the
   --  entry is made unusable (Undo_None) and History_Entry_Usable drops it,
   --  its replaced originals still named for release.
   procedure Assemble (Value : in out Files.Undo_History.Undo_Entry; Columns : Field_Columns) is
      function Matches (Which, Leading : Vector_Field; Optional : Boolean := False) return Boolean is
        (Columns (Which).Length = Columns (Leading).Length or else (Optional and then Columns (Which).Is_Empty));

      function At_Index (Which : Vector_Field; Index : Positive) return Unbounded_String is
        (if Index <= Columns (Which).Last_Index then Columns (Which) (Index) else Null_Unbounded_String);
   begin
      for Index in 1 .. Natural (Columns (From_Field).Length) loop
         Value.Items.Append
           (Files.Undo_History.Undo_Item'
              (From          => Columns (From_Field) (Index),
               To            => At_Index (To_Field, Index),
               Forward       => At_Index (Forward_Field, Index),
               Identity      => At_Index (Created_Identities_Field, Index),
               Tree_Revision => At_Index (Created_Tree_Revisions_Field, Index)));
      end loop;
      for Index in 1 .. Natural (Columns (Restore_Trash_Field).Length) loop
         Value.Replaced.Append
           (Files.Undo_History.Replaced_Original'
              (Trash    => Columns (Restore_Trash_Field) (Index),
               Identity => At_Index (Restore_Identities_Field, Index),
               Target   => At_Index (Restore_Targets_Field, Index)));
      end loop;
      for Index in 1 .. Natural (Columns (Kept_Copies_Field).Length) loop
         Value.Kept.Append
           (Files.Undo_History.Kept_Copy'
              (Path          => Columns (Kept_Copies_Field) (Index),
               Identity      => At_Index (Kept_Copy_Identities_Field, Index),
               Tree_Revision => At_Index (Kept_Copy_Tree_Revisions_Field, Index)));
      end loop;
      Value.Reverse_Completed := Columns (Reverse_Completed_Field);
      Value.Restores_Completed := Columns (Restores_Completed_Field);
      Value.Forward_Completed := Columns (Forward_Completed_Field);
      Value.Copy_Records := Columns (Copy_Records_Field);
      if not (Matches (To_Field, From_Field, Optional => True)
              and then Matches (Forward_Field, From_Field, Optional => True)
              and then Matches (Created_Identities_Field, From_Field)
              and then Matches (Created_Tree_Revisions_Field, From_Field)
              and then Matches (Restore_Identities_Field, Restore_Trash_Field)
              and then Matches (Restore_Targets_Field, Restore_Trash_Field)
              and then Matches (Kept_Copy_Identities_Field, Kept_Copies_Field)
              and then Matches (Kept_Copy_Tree_Revisions_Field, Kept_Copies_Field))
      then
         Value.Kind := Files.Undo_History.Undo_None;
      end if;
   end Assemble;

   procedure Write_Entry
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value  : Files.Undo_History.Undo_Entry;
      Total  : in out Byte_Count;
      Fields : in out Natural)
   is
   begin
      if Total > Max_Journal_Bytes - 32 then
         raise Ada.Directories.Use_Error;
      end if;
      Total := Total + 32;
      Files.Undo_History.Undo_Action_Kind'Output (Stream, Value.Kind);
      for Which in Leading_Field loop
         Write_Vector (Stream, Column (Value, Which), Total, Fields);
      end loop;
      Files.Undo_History.Undo_Create_Kind'Output (Stream, Value.Create_Kind);
      Boolean'Output (Stream, Value.Redoable);
      for Which in Trailing_Field loop
         Write_Vector (Stream, Column (Value, Which), Total, Fields);
      end loop;
      Natural'Output (Stream, Value.Sequence);
   end Write_Entry;

   function Read_Entry
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Fields : in out Natural;
      Version_1 : Boolean)
      return Files.Undo_History.Undo_Entry
   is
      Result  : Files.Undo_History.Undo_Entry;
      Columns : Field_Columns;
   begin
      Result.Kind := Files.Undo_History.Undo_Action_Kind'Input (Stream);
      for Which in Leading_Field loop
         Columns (Which) := Read_Vector (Stream, Fields);
      end loop;
      Result.Create_Kind := Files.Undo_History.Undo_Create_Kind'Input (Stream);
      Result.Redoable := Boolean'Input (Stream);
      for Which in Trailing_Field loop
         if Which in Version_1_Field or else not Version_1 then
            Columns (Which) := Read_Vector (Stream, Fields);
         end if;
      end loop;
      if not Version_1 then
         Result.Sequence := Natural'Input (Stream);
      end if;
      Assemble (Result, Columns);
      return Result;
   end Read_Entry;

   procedure Write_Stack
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value  : Files.Undo_History.Undo_Entry_Vectors.Vector;
      Total  : in out Byte_Count;
      Fields : in out Natural)
   is
   begin
      if Value.Length > Ada.Containers.Count_Type (Max_History_Entries) then
         raise Ada.Directories.Use_Error;
      end if;
      Natural'Output (Stream, Natural (Value.Length));
      for Item of Value loop
         Write_Entry (Stream, Item, Total, Fields);
      end loop;
   end Write_Stack;

   function Read_Stack
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Fields : in out Natural;
      Version_1 : Boolean)
      return Files.Undo_History.Undo_Entry_Vectors.Vector
   is
      Count : constant Natural := Natural'Input (Stream);
      Result : Files.Undo_History.Undo_Entry_Vectors.Vector;
   begin
      if Count > Max_History_Entries then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Result.Reserve_Capacity (Ada.Containers.Count_Type (Count));
      for Index in 1 .. Count loop
         Result.Append (Read_Entry (Stream, Fields, Version_1));
      end loop;
      return Result;
   end Read_Stack;

   --  What Value adds to the journal, counted as Write_Entry counts it.
   procedure Add_Cost (Value : Files.Undo_History.Undo_Entry; Bytes, Fields : in out Long_Long_Integer) is
      procedure Add (Vector : Files.Types.String_Vectors.Vector) is
      begin
         Bytes := Bytes + 16;
         Fields := Fields + Long_Long_Integer (Vector.Length);
         for Item of Vector loop
            Bytes := Bytes + Byte_Count (Length (Item)) + 16;
            --  A field Write_Vector refuses makes the whole entry unfit.
            if Length (Item) > Max_Field_Length then
               Bytes := Bytes + Byte_Count (Max_Journal_Bytes);
            end if;
         end loop;
      end Add;
   begin
      Bytes := Bytes + 32;
      for Which in Vector_Field loop
         Add (Column (Value, Which));
      end loop;
      Bytes := Bytes + 16;
   end Add_Cost;

   --  The stacks less their oldest entries, as many as the journal's caps
   --  need: one very large action (a move of a hundred thousand files) must
   --  not make every later save fail -- and with it every operation's start
   --  and every Undo. The newest entry of each stack (the one in progress)
   --  is kept while it fits on its own; one too large for the journal even
   --  alone, newest or not, is left out first rather than failing the save
   --  or costing the others their place. The window keeps
   --  the whole history in memory, the journal only what a crash could
   --  recover; Left_Out gains the Sequence of each entry left out, so a
   --  window merging a helper's journal keeps them (Files.Model.History.Merge).
   procedure Fit
     (Undo, Redo : in out Files.Undo_History.Undo_Entry_Vectors.Vector;
      Header     : Byte_Count;
      Left_Out   : in out Files.Undo_History.Sequence_Vectors.Vector)
   is
      Margin : constant Long_Long_Integer := 1024;
      function Over return Boolean is
         Bytes  : Long_Long_Integer :=
           Header + Margin + 16 * (Long_Long_Integer (Left_Out.Length) + 1);
         Fields : Long_Long_Integer := 0;
      begin
         for Item of Undo loop
            Add_Cost (Item, Bytes, Fields);
         end loop;
         for Item of Redo loop
            Add_Cost (Item, Bytes, Fields);
         end loop;
         return Bytes > Max_Journal_Bytes or else Fields > Max_Journal_Fields;
      end Over;

      function Cost (Value : Files.Undo_History.Undo_Entry) return Long_Long_Integer is
         Bytes, Fields : Long_Long_Integer := 0;
      begin
         Add_Cost (Value, Bytes, Fields);
         return Bytes + 16 * Fields;
      end Cost;

      procedure Leave_Out (Stack : in out Files.Undo_History.Undo_Entry_Vectors.Vector; Oldest : Boolean) is
         Sequence : constant Natural :=
           (if Oldest then Stack.First_Element.Sequence else Stack.Last_Element.Sequence);
      begin
         if Sequence > 0 and then not Left_Out.Contains (Sequence) then
            Left_Out.Append (Sequence);
         end if;
         if Oldest then
            Stack.Delete_First;
         else
            Stack.Delete_Last;
         end if;
      end Leave_Out;

      --  Whether Value does not fit the journal even alone.
      function Unfit (Value : Files.Undo_History.Undo_Entry) return Boolean is
         Bytes  : Long_Long_Integer := Header + Margin;
         Fields : Long_Long_Integer := 0;
      begin
         Add_Cost (Value, Bytes, Fields);
         return Bytes > Max_Journal_Bytes or else Fields > Max_Journal_Fields;
      end Unfit;

      --  Leave out every entry too large for the journal even alone ("not
      --  journaled"), wherever it is, rather than costing the entries around
      --  it their place.
      procedure Leave_Out_Unfit (Stack : in out Files.Undo_History.Undo_Entry_Vectors.Vector) is
         Index : Natural := Stack.Last_Index;
      begin
         while Index >= Stack.First_Index loop
            if Unfit (Stack (Index)) then
               if Stack (Index).Sequence > 0 and then not Left_Out.Contains (Stack (Index).Sequence) then
                  Left_Out.Append (Stack (Index).Sequence);
               end if;
               Stack.Delete (Index);
            end if;
            Index := Index - 1;
         end loop;
      end Leave_Out_Unfit;
   begin
      Leave_Out_Unfit (Undo);
      Leave_Out_Unfit (Redo);
      while Over loop
         if Undo.Length > 1 then
            Leave_Out (Undo, Oldest => True);
         elsif Redo.Length > 1 then
            Leave_Out (Redo, Oldest => True);
         elsif not Undo.Is_Empty
           and then (Redo.Is_Empty or else Cost (Undo.First_Element) >= Cost (Redo.First_Element))
         then
            --  The two newest do not fit together: the larger is left out.
            Leave_Out (Undo, Oldest => False);
         elsif not Redo.Is_Empty then
            Leave_Out (Redo, Oldest => False);
         else
            exit;
         end if;
      end loop;
   end Fit;

   --  Left_Out pruned to what it can still mean: each Sequence once, none
   --  the written stacks hold (those are journaled), none at or past Next
   --  (never handed out). Past Max_Unjournaled the oldest markers go, rather
   --  than failing the save, which a job's start and its checkpoints
   --  require: each one gone is added to Dropped, which the journal carries
   --  so the window retires those entries on merge, releasing what they
   --  preserved (Files.Model.History.Merge).
   function Pruned_Left_Out
     (Left_Out   : Files.Undo_History.Sequence_Vectors.Vector;
      Undo, Redo : Files.Undo_History.Undo_Entry_Vectors.Vector;
      Next       : Positive;
      Dropped    : in out Files.Undo_History.Sequence_Vectors.Vector) return Files.Undo_History.Sequence_Vectors.Vector
   is
      package Sequence_Sets is new Ada.Containers.Ordered_Sets (Element_Type => Positive);
      package Sequence_Sorting is new Files.Undo_History.Sequence_Vectors.Generic_Sorting;
      Held, Listed : Sequence_Sets.Set;
      Result : Files.Undo_History.Sequence_Vectors.Vector;
   begin
      for Action of Undo loop
         if Action.Sequence > 0 then
            Held.Include (Action.Sequence);
         end if;
      end loop;
      for Action of Redo loop
         if Action.Sequence > 0 then
            Held.Include (Action.Sequence);
         end if;
      end loop;
      for Sequence of Left_Out loop
         if Sequence < Next and then not Held.Contains (Sequence) and then not Listed.Contains (Sequence) then
            Listed.Include (Sequence);
            Result.Append (Sequence);
         end if;
      end loop;
      if Natural (Result.Length) > Max_Unjournaled then
         declare
            Gone : constant Natural := Natural (Result.Length) - Max_Unjournaled;
         begin
            Files.Diagnostics.Trace ("Files.History_Journal", "unjournaled_dropped=" & Natural'Image (Gone));
            Sequence_Sorting.Sort (Result);
            for Index in Result.First_Index .. Result.First_Index + Gone - 1 loop
               Dropped.Append (Result (Index));
            end loop;
            Result.Delete_First (Ada.Containers.Count_Type (Gone));
         end;
      end if;
      return Result;
   end Pruned_Left_Out;

   --  Dropped pruned as Left_Out is, and of every Sequence Left_Out lists
   --  (that entry is listed after all); past Max_Unjournaled -- more than
   --  any history holds -- the oldest go, with a trace.
   function Pruned_Dropped
     (Dropped    : Files.Undo_History.Sequence_Vectors.Vector;
      Left_Out   : Files.Undo_History.Sequence_Vectors.Vector;
      Undo, Redo : Files.Undo_History.Undo_Entry_Vectors.Vector;
      Next       : Positive) return Files.Undo_History.Sequence_Vectors.Vector
   is
      package Sequence_Sets is new Ada.Containers.Ordered_Sets (Element_Type => Positive);
      package Sequence_Sorting is new Files.Undo_History.Sequence_Vectors.Generic_Sorting;
      Excluded : Sequence_Sets.Set;
      Result   : Files.Undo_History.Sequence_Vectors.Vector;
   begin
      for Action of Undo loop
         if Action.Sequence > 0 then
            Excluded.Include (Action.Sequence);
         end if;
      end loop;
      for Action of Redo loop
         if Action.Sequence > 0 then
            Excluded.Include (Action.Sequence);
         end if;
      end loop;
      for Sequence of Left_Out loop
         Excluded.Include (Sequence);
      end loop;
      for Sequence of Dropped loop
         if Sequence < Next and then not Excluded.Contains (Sequence) then
            Excluded.Include (Sequence);
            Result.Append (Sequence);
         end if;
      end loop;
      if Natural (Result.Length) > Max_Unjournaled then
         Files.Diagnostics.Trace
           ("Files.History_Journal",
            "dropped_forgotten=" & Natural'Image (Natural (Result.Length) - Max_Unjournaled));
         Sequence_Sorting.Sort (Result);
         Result.Delete_First (Result.Length - Ada.Containers.Count_Type (Max_Unjournaled));
      end if;
      return Result;
   end Pruned_Dropped;

   function Journals_Newest
     (History : Files.Undo_History.Undo_History_State;
      Side    : Files.Undo_History.History_Side) return Boolean
   is
      use type Files.Undo_History.History_Side;
      Redo       : constant Boolean := Side = Files.Undo_History.Redo_Side;
      Undo_Stack : Files.Undo_History.Undo_Entry_Vectors.Vector := History.Undo_Stack;
      Redo_Stack : Files.Undo_History.Undo_Entry_Vectors.Vector := History.Redo_Stack;
      Original   : constant Files.Undo_History.Undo_Entry_Vectors.Vector := (if Redo then Redo_Stack else Undo_Stack);
      Left_Out   : Files.Undo_History.Sequence_Vectors.Vector := History.Journal.Unjournaled;
   begin
      if Original.Is_Empty then
         return True;
      end if;
      Fit (Undo_Stack, Redo_Stack, Journal_Header'Length + 32, Left_Out);
      declare
         Kept : constant Files.Undo_History.Undo_Entry_Vectors.Vector := (if Redo then Redo_Stack else Undo_Stack);
      begin
         return not Kept.Is_Empty and then Kept.Last_Element.Sequence = Original.Last_Element.Sequence;
      end;
   end Journals_Newest;

   procedure Save_Stacks
     (Directory : String;
      Undo, Redo : Files.Undo_History.Undo_Entry_Vectors.Vector;
      Mode : Save_Mode := Best_Effort;
      State : Files.Undo_History.History_Journal_State := (others => <>))
   is
      Kept_Undo : Files.Undo_History.Undo_Entry_Vectors.Vector := Undo;
      Kept_Redo : Files.Undo_History.Undo_Entry_Vectors.Vector := Redo;
      Total : Byte_Count := Journal_Header'Length + 32;
      Fields : Natural := 0;
      Target : constant String := Hostkit.Fs.Join (Directory, "history");

      --  Past every Sequence handed out: the journal's own count, or past
      --  an entry an older journal numbered beyond it.
      function Sequence_Bound return Positive is
         Result : Positive := State.Next_Sequence;
      begin
         for Action of Undo loop
            Result := Positive'Max (Result, Action.Sequence + 1);
         end loop;
         for Action of Redo loop
            Result := Positive'Max (Result, Action.Sequence + 1);
         end loop;
         return Result;
      end Sequence_Bound;

      procedure Write_Journal (Output : not null access Ada.Streams.Root_Stream_Type'Class) is
         Next     : constant Positive := Sequence_Bound;
         Dropped  : Files.Undo_History.Sequence_Vectors.Vector := State.Dropped;
         --  Pruned before Fit too, so stale markers cost no entry its place.
         Left_Out : Files.Undo_History.Sequence_Vectors.Vector :=
           Pruned_Left_Out (State.Unjournaled, Undo, Redo, Next, Dropped);
      begin
         String'Output (Output, Journal_Header);
         Fit (Kept_Undo, Kept_Redo, Total, Left_Out);
         Left_Out := Pruned_Left_Out (Left_Out, Kept_Undo, Kept_Redo, Next, Dropped);
         Dropped := Pruned_Dropped (Dropped, Left_Out, Kept_Undo, Kept_Redo, Next);
         Natural'Output (Output, State.Next_Sequence);
         Boolean'Output (Output, State.Redo_Retired);
         Natural'Output (Output, Natural (Left_Out.Length));
         for Sequence of Left_Out loop
            Positive'Output (Output, Sequence);
         end loop;
         Natural'Output (Output, Natural (Dropped.Length));
         for Sequence of Dropped loop
            Positive'Output (Output, Sequence);
         end loop;
         Total := Total + 16 * Byte_Count (Natural (Left_Out.Length) + Natural (Dropped.Length) + 3);
         Write_Stack (Output, Kept_Undo, Total, Fields);
         Write_Stack (Output, Kept_Redo, Total, Fields);
      end Write_Journal;
   begin
      if Directory = "" then
         return;
      end if;
      if not Valid_Directory (Directory)
        or else Hostkit.Fs.Is_Link (Directory)
        --  refusal-safe: a refused folder refuses the save
        or else not Files.Fs_Primitives.Exists (Directory)
        or else Files.Fs_Primitives.Kind (Directory) /= Ada.Directories.Directory
      then
         raise Ada.Directories.Use_Error;
      end if;
      --  A temporary a crash left behind is passed over (Write_And_Publish),
      --  so it never refuses a later save; a Target that is a link or not a
      --  file refuses it there.
      if not Files.Durable_Writes.Published (Files.Durable_Writes.Write_And_Publish (Target, Write_Journal'Access))
      then
         if Mode = Must_Commit then
            raise Ada.Directories.Use_Error;
         end if;
         --  A best-effort save that did not commit leaves the journal as
         --  it was: traced, as a refused save is below.
         Files.Diagnostics.Trace ("Files.History_Journal", "journal_not_published=" & Target);
      end if;
   exception
      when Failure : others =>
         if Mode = Must_Commit then
            raise;
         end if;
         Files.Diagnostics.Note (Failure, "Files.History_Journal");
   end Save_Stacks;

   procedure Save (History : Files.Undo_History.Undo_History_State; Mode : Save_Mode := Best_Effort) is
   begin
      Save_To (Files.Job_Context.Directory, History, Mode);
   end Save;

   procedure Save_To
     (Directory : String;
      History   : Files.Undo_History.Undo_History_State;
      Mode      : Save_Mode := Best_Effort) is
   begin
      Save_Stacks (Directory, History.Undo_Stack, History.Redo_Stack, Mode, History.Journal);
   end Save_To;

   --  When the journal was last written by Checkpoint.
   Last_Checkpoint     : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
   Checkpoint_Interval : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (1);

   procedure Checkpoint
     (History : Files.Undo_History.Undo_History_State;
      Action  : Files.Undo_History.Undo_Entry;
      Side    : Files.Undo_History.History_Side;
      Timing  : Checkpoint_Timing := Write_Now)
   is
      use type Ada.Real_Time.Time;
      use type Files.Undo_History.History_Side;
      Undo_Stack : Files.Undo_History.Undo_Entry_Vectors.Vector;
      Redo_Stack : Files.Undo_History.Undo_Entry_Vectors.Vector;
   begin
      if Timing = Within_Second and then Ada.Real_Time.Clock < Last_Checkpoint + Checkpoint_Interval then
         return;
      end if;
      Undo_Stack := History.Undo_Stack;
      Redo_Stack := History.Redo_Stack;
      if Side = Files.Undo_History.Redo_Side then
         Redo_Stack.Append (Action);
      else
         Undo_Stack.Append (Action);
      end if;
      Save_Stacks
        (Files.Job_Context.Directory, Undo_Stack, Redo_Stack,
         Mode => Must_Commit, State => History.Journal);
      Last_Checkpoint := Ada.Real_Time.Clock;
   end Checkpoint;

   --  Read the journal in Directory; False when there is none to read.
   function Read_Journal
     (Directory : String;
      Undo, Redo : out Files.Undo_History.Undo_Entry_Vectors.Vector;
      State : out Files.Undo_History.History_Journal_State) return Boolean
   is
      Input : aliased Files.Lease_Streams.Input_Stream;
      Fields : Natural := 0;
      Path : constant String := Hostkit.Fs.Join (Directory, "history");
   begin
      Undo.Clear;
      Redo.Clear;
      State := (others => <>);
      if Refused_Reads > 0 then
         Refused_Reads := Refused_Reads - 1;
         raise Ada.Directories.Use_Error;
      end if;
      --  None to read only when the journal is gone for sure (no folder is
      --  no journal either). One the host will not answer for, or will not
      --  open, is no absence: it raises, and the caller tries again. Nor is
      --  a transport that is not a valid folder path, or is a link: that is
      --  a refusal to read through it, never proof there is no journal.
      if not Valid_Directory (Directory) or else Hostkit.Fs.Is_Link (Directory) then
         raise Ada.Directories.Use_Error;
      end if;
      if Files.Fs_Primitives.Entry_Is_Absent (Path) then
         return False;
      end if;
      if Files.Lease_Streams.Open (Path, Input) /= Hostkit.Lease_Files.Opened then
         raise Ada.Directories.Use_Error;
      end if;
      if Files.Lease_Streams.Size (Input) >
        Long_Long_Integer (Max_Journal_Bytes)
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      declare
         Header : constant String := Files.Bounded_Streams.Input_String (Input'Access, Journal_Header'Length);
         Version_1 : constant Boolean := Header = Version_1_Header;
         Version_2 : constant Boolean := Header = Version_2_Header;

         --  A list of at most Max_Unjournaled Sequences.
         procedure Read_Sequences (Into : in out Files.Undo_History.Sequence_Vectors.Vector) is
            Count : constant Natural := Natural'Input (Input'Access);
         begin
            if Count > Max_Unjournaled then
               raise Ada.IO_Exceptions.Data_Error;
            end if;
            for Index in 1 .. Count loop
               Into.Append (Positive'Input (Input'Access));
            end loop;
         end Read_Sequences;
      begin
         if Header /= Journal_Header and then not Version_1 and then not Version_2 then
            raise Ada.IO_Exceptions.Data_Error;
         end if;
         if not Version_1 then
            State.Next_Sequence := Positive'Max (1, Natural'Input (Input'Access));
            State.Redo_Retired := Boolean'Input (Input'Access);
            Read_Sequences (State.Unjournaled);
            if not Version_2 then
               Read_Sequences (State.Dropped);
            end if;
         end if;
         Undo := Read_Stack (Input'Access, Fields, Version_1);
         Redo := Read_Stack (Input'Access, Fields, Version_1);
      end;
      if not Files.Lease_Streams.End_Of_Stream (Input) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Files.Lease_Streams.Release (Input);
      return True;
   exception
      when others =>
         Files.Lease_Streams.Release (Input);
         raise;
   end Read_Journal;

   function Read (Directory : String; Contents : out Journal_Contents) return Read_Outcome is
   begin
      if not Read_Journal (Directory, Contents.Undo, Contents.Redo, Contents.State) then
         return No_Journal;
      end if;
      return Read_Whole;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.History_Journal");
         Contents := (others => <>);
         return Unreadable;
   end Read;
end Files.History_Journal;
