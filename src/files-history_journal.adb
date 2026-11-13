with Files.Diagnostics;
with Ada.Real_Time;
with Ada.Containers;
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
   --  kept copies and Sequence. Version 1 journals still read, without them.
   Journal_Header : constant String := "files-history-2";
   Version_1_Header : constant String := "files-history-1";
   Max_Journal_Bytes : constant := 64 * 1024 * 1024;
   Max_History_Entries : constant := 200;
   Max_Vector_Fields : constant := 1_000_000;
   Max_Journal_Fields : constant := 2_000_000;
   Max_Field_Length : constant := 32 * 1024;
   Max_Unjournaled : constant := 4 * Max_History_Entries;

   function Valid_Directory (Directory : String) return Boolean is
     (Files.Path_Checks.Valid_Absolute_Path (Directory, Max_Field_Length));

   procedure Write_Vector
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value  : Files.Types.String_Vectors.Vector;
      Total  : in out Natural;
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
           or else Length (Item) + 16 > Max_Journal_Bytes - Total
         then
            raise Ada.Directories.Use_Error;
         end if;
         Total := Total + Length (Item) + 16;
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

   procedure Write_Entry
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value  : Files.Model.Undo_Entry;
      Total  : in out Natural;
      Fields : in out Natural)
   is
   begin
      if Total > Max_Journal_Bytes - 32 then
         raise Ada.Directories.Use_Error;
      end if;
      Total := Total + 32;
      Files.Model.Undo_Action_Kind'Output (Stream, Value.Kind);
      Write_Vector (Stream, Value.From, Total, Fields);
      Write_Vector (Stream, Value.To, Total, Fields);
      Write_Vector (Stream, Value.Forward, Total, Fields);
      Files.Model.Undo_Create_Kind'Output (Stream, Value.Create_Kind);
      Boolean'Output (Stream, Value.Redoable);
      Write_Vector (Stream, Value.Restore_Trash, Total, Fields);
      Write_Vector (Stream, Value.Restore_Identities, Total, Fields);
      Write_Vector (Stream, Value.Restore_Targets, Total, Fields);
      Write_Vector (Stream, Value.Reverse_Completed, Total, Fields);
      Write_Vector (Stream, Value.Restores_Completed, Total, Fields);
      Write_Vector (Stream, Value.Forward_Completed, Total, Fields);
      Write_Vector (Stream, Value.Copy_Records, Total, Fields);
      Write_Vector (Stream, Value.Created_Identities, Total, Fields);
      Write_Vector (Stream, Value.Created_Tree_Revisions, Total, Fields);
      Write_Vector (Stream, Value.Kept_Copies, Total, Fields);
      Write_Vector (Stream, Value.Kept_Copy_Identities, Total, Fields);
      Write_Vector (Stream, Value.Kept_Copy_Tree_Revisions, Total, Fields);
      Natural'Output (Stream, Value.Sequence);
   end Write_Entry;

   function Read_Entry
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Fields : in out Natural;
      Version_1 : Boolean)
      return Files.Model.Undo_Entry
   is
      Result : Files.Model.Undo_Entry;
   begin
      Result.Kind := Files.Model.Undo_Action_Kind'Input (Stream);
      Result.From := Read_Vector (Stream, Fields);
      Result.To := Read_Vector (Stream, Fields);
      Result.Forward := Read_Vector (Stream, Fields);
      Result.Create_Kind := Files.Model.Undo_Create_Kind'Input (Stream);
      Result.Redoable := Boolean'Input (Stream);
      Result.Restore_Trash := Read_Vector (Stream, Fields);
      Result.Restore_Identities := Read_Vector (Stream, Fields);
      Result.Restore_Targets := Read_Vector (Stream, Fields);
      Result.Reverse_Completed := Read_Vector (Stream, Fields);
      Result.Restores_Completed := Read_Vector (Stream, Fields);
      Result.Forward_Completed := Read_Vector (Stream, Fields);
      Result.Copy_Records := Read_Vector (Stream, Fields);
      Result.Created_Identities := Read_Vector (Stream, Fields);
      Result.Created_Tree_Revisions := Read_Vector (Stream, Fields);
      if not Version_1 then
         Result.Kept_Copies := Read_Vector (Stream, Fields);
         Result.Kept_Copy_Identities := Read_Vector (Stream, Fields);
         Result.Kept_Copy_Tree_Revisions := Read_Vector (Stream, Fields);
         Result.Sequence := Natural'Input (Stream);
      end if;
      return Result;
   end Read_Entry;

   procedure Write_Stack
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value  : Files.Model.Undo_Entry_Vectors.Vector;
      Total  : in out Natural;
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
      return Files.Model.Undo_Entry_Vectors.Vector
   is
      Count : constant Natural := Natural'Input (Stream);
      Result : Files.Model.Undo_Entry_Vectors.Vector;
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
   procedure Add_Cost (Value : Files.Model.Undo_Entry; Bytes, Fields : in out Long_Long_Integer) is
      procedure Add (Vector : Files.Types.String_Vectors.Vector) is
      begin
         Bytes := Bytes + 16;
         Fields := Fields + Long_Long_Integer (Vector.Length);
         for Item of Vector loop
            Bytes := Bytes + Long_Long_Integer (Length (Item)) + 16;
            --  A field Write_Vector refuses makes the whole entry unfit.
            if Length (Item) > Max_Field_Length then
               Bytes := Bytes + Long_Long_Integer (Max_Journal_Bytes);
            end if;
         end loop;
      end Add;
   begin
      Bytes := Bytes + 32;
      Add (Value.From);
      Add (Value.To);
      Add (Value.Forward);
      Add (Value.Restore_Trash);
      Add (Value.Restore_Identities);
      Add (Value.Restore_Targets);
      Add (Value.Reverse_Completed);
      Add (Value.Restores_Completed);
      Add (Value.Forward_Completed);
      Add (Value.Copy_Records);
      Add (Value.Created_Identities);
      Add (Value.Created_Tree_Revisions);
      Add (Value.Kept_Copies);
      Add (Value.Kept_Copy_Identities);
      Add (Value.Kept_Copy_Tree_Revisions);
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
   --  window merging a helper's journal keeps them (Files.Model.Merge_History).
   procedure Fit
     (Undo, Redo : in out Files.Model.Undo_Entry_Vectors.Vector;
      Header     : Natural;
      Left_Out   : in out Files.Model.Sequence_Vectors.Vector)
   is
      Margin : constant Long_Long_Integer := 1024;
      function Over return Boolean is
         Bytes  : Long_Long_Integer :=
           Long_Long_Integer (Header) + Margin + 16 * (Long_Long_Integer (Left_Out.Length) + 1);
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

      function Cost (Value : Files.Model.Undo_Entry) return Long_Long_Integer is
         Bytes, Fields : Long_Long_Integer := 0;
      begin
         Add_Cost (Value, Bytes, Fields);
         return Bytes + 16 * Fields;
      end Cost;

      procedure Leave_Out (Stack : in out Files.Model.Undo_Entry_Vectors.Vector; Oldest : Boolean) is
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
      function Unfit (Value : Files.Model.Undo_Entry) return Boolean is
         Bytes  : Long_Long_Integer := Long_Long_Integer (Header) + Margin;
         Fields : Long_Long_Integer := 0;
      begin
         Add_Cost (Value, Bytes, Fields);
         return Bytes > Max_Journal_Bytes or else Fields > Max_Journal_Fields;
      end Unfit;

      --  Leave out every entry too large for the journal even alone ("not
      --  journaled"), wherever it is, rather than costing the entries around
      --  it their place.
      procedure Leave_Out_Unfit (Stack : in out Files.Model.Undo_Entry_Vectors.Vector) is
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

   function Journals_Newest (Model : Files.Model.Window_Model; Redo : Boolean) return Boolean is
      Undo_Stack : Files.Model.Undo_Entry_Vectors.Vector := Files.Model.Undo_History (Model);
      Redo_Stack : Files.Model.Undo_Entry_Vectors.Vector := Files.Model.Redo_History (Model);
      Original   : constant Files.Model.Undo_Entry_Vectors.Vector := (if Redo then Redo_Stack else Undo_Stack);
      Left_Out   : Files.Model.Sequence_Vectors.Vector := Files.Model.History_State (Model).Unjournaled;
   begin
      if Original.Is_Empty then
         return True;
      end if;
      Fit (Undo_Stack, Redo_Stack, Journal_Header'Length + 32, Left_Out);
      declare
         Kept : constant Files.Model.Undo_Entry_Vectors.Vector := (if Redo then Redo_Stack else Undo_Stack);
      begin
         return not Kept.Is_Empty and then Kept.Last_Element.Sequence = Original.Last_Element.Sequence;
      end;
   end Journals_Newest;

   procedure Save_Stacks
     (Directory : String;
      Undo, Redo : Files.Model.Undo_Entry_Vectors.Vector;
      Required : Boolean := False;
      State : Files.Model.History_Journal_State := (others => <>))
   is
      Kept_Undo : Files.Model.Undo_Entry_Vectors.Vector := Undo;
      Kept_Redo : Files.Model.Undo_Entry_Vectors.Vector := Redo;
      Published : Files.Durable_Writes.Publication_Result;
      Total : Natural := Journal_Header'Length + 32;
      Fields : Natural := 0;
      Temporary : constant String := Hostkit.Fs.Join (Directory, "history.tmp");
      Target : constant String := Hostkit.Fs.Join (Directory, "history");
      Temporary_Identity : Unbounded_String;

      procedure Write_Journal (Output : not null access Ada.Streams.Root_Stream_Type'Class) is
         Left_Out : Files.Model.Sequence_Vectors.Vector := State.Unjournaled;
      begin
         String'Output (Output, Journal_Header);
         Fit (Kept_Undo, Kept_Redo, Total, Left_Out);
         if Natural (Left_Out.Length) > Max_Unjournaled then
            raise Ada.Directories.Use_Error;
         end if;
         Natural'Output (Output, State.Next_Sequence);
         Boolean'Output (Output, State.Redo_Retired);
         Natural'Output (Output, Natural (Left_Out.Length));
         for Sequence of Left_Out loop
            Positive'Output (Output, Sequence);
         end loop;
         Total := Total + 16 * (Natural (Left_Out.Length) + 2);
         Write_Stack (Output, Kept_Undo, Total, Fields);
         Write_Stack (Output, Kept_Redo, Total, Fields);
      end Write_Journal;
   begin
      if Directory = "" then
         return;
      end if;
      if not Valid_Directory (Directory)
        or else Hostkit.Fs.Is_Link (Directory)
        or else not Files.Fs_Primitives.Exists (Directory)
        or else Files.Fs_Primitives.Kind (Directory) /= Ada.Directories.Directory
        or else Hostkit.Fs.Is_Link (Temporary)
        or else (Files.Fs_Primitives.Exists (Temporary)
          and then Files.Fs_Primitives.Kind (Temporary) /= Ada.Directories.Ordinary_File)
        or else Hostkit.Fs.Is_Link (Target)
        or else (Files.Fs_Primitives.Exists (Target)
          and then Files.Fs_Primitives.Kind (Target) /= Ada.Directories.Ordinary_File)
      then
         raise Ada.Directories.Use_Error;
      end if;
      --  A temporary a crash left behind (a plain file, checked above) would
      --  refuse every later save: the journal is ours, so it goes.
      if Files.Fs_Primitives.Exists (Temporary) then
         Files.Fs_Primitives.Delete_File (Temporary);
      end if;
      Files.Durable_Writes.Write_Private_File (Temporary, Write_Journal'Access, Temporary_Identity);
      Published := Files.Durable_Writes.Publish
        (Temporary, Target);
      if Files.Durable_Writes.Published (Published) then
         Temporary_Identity := Null_Unbounded_String;
      else
         Files.Durable_Writes.Remove_Owned (Temporary, To_String (Temporary_Identity));
         if Required then
            raise Ada.Directories.Use_Error;
         end if;
      end if;
   exception
      when Failure : others =>
         Files.Durable_Writes.Remove_Owned (Temporary, To_String (Temporary_Identity));
         if Required then
            raise;
         end if;
         Files.Diagnostics.Note (Failure, "Files.History_Journal");
   end Save_Stacks;

   procedure Save (Model : Files.Model.Window_Model; Required : Boolean := False) is
   begin
      Save_To (Files.Job_Context.Directory, Model, Required);
   end Save;

   procedure Save_To (Directory : String; Model : Files.Model.Window_Model; Required : Boolean := False) is
   begin
      Save_Stacks
        (Directory, Files.Model.Undo_History (Model),
         Files.Model.Redo_History (Model), Required, Files.Model.History_State (Model));
   end Save_To;

   --  When the journal was last written by Checkpoint.
   Last_Checkpoint     : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
   Checkpoint_Interval : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (1);

   procedure Checkpoint
     (Model : Files.Model.Window_Model; Action : Files.Model.Undo_Entry; Redo : Boolean; Force : Boolean := True)
   is
      use type Ada.Real_Time.Time;
      Undo_Stack : Files.Model.Undo_Entry_Vectors.Vector;
      Redo_Stack : Files.Model.Undo_Entry_Vectors.Vector;
   begin
      if not Force and then Ada.Real_Time.Clock < Last_Checkpoint + Checkpoint_Interval then
         return;
      end if;
      Undo_Stack := Files.Model.Undo_History (Model);
      Redo_Stack := Files.Model.Redo_History (Model);
      if Redo then
         Redo_Stack.Append (Action);
      else
         Undo_Stack.Append (Action);
      end if;
      Save_Stacks
        (Files.Job_Context.Directory, Undo_Stack, Redo_Stack,
         Required => True, State => Files.Model.History_State (Model));
      Last_Checkpoint := Ada.Real_Time.Clock;
   end Checkpoint;

   --  Read the journal in Directory; False when there is none to read.
   function Read_Journal
     (Directory : String;
      Undo, Redo : out Files.Model.Undo_Entry_Vectors.Vector;
      State : out Files.Model.History_Journal_State) return Boolean
   is
      Input : aliased Files.Lease_Streams.Input_Stream;
      Fields : Natural := 0;
      Path : constant String := Hostkit.Fs.Join (Directory, "history");
   begin
      Undo.Clear;
      Redo.Clear;
      State := (others => <>);
      if not Valid_Directory (Directory)
        or else Hostkit.Fs.Is_Link (Directory)
        or else not Files.Fs_Primitives.Exists (Directory)
        or else Files.Fs_Primitives.Kind (Directory) /= Ada.Directories.Directory
        or else not Files.Fs_Primitives.Exists (Path)
        or else Files.Lease_Streams.Open (Path, Input) /=
          Hostkit.Lease_Files.Opened
      then
         return False;
      end if;
      if Files.Lease_Streams.Size (Input) >
        Long_Long_Integer (Max_Journal_Bytes)
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      declare
         Header : constant String := Files.Bounded_Streams.Input_String (Input'Access, Journal_Header'Length);
         Version_1 : constant Boolean := Header = Version_1_Header;
      begin
         if Header /= Journal_Header and then not Version_1 then
            raise Ada.IO_Exceptions.Data_Error;
         end if;
         if not Version_1 then
            State.Next_Sequence := Positive'Max (1, Natural'Input (Input'Access));
            State.Redo_Retired := Boolean'Input (Input'Access);
            declare
               Count : constant Natural := Natural'Input (Input'Access);
            begin
               if Count > Max_Unjournaled then
                  raise Ada.IO_Exceptions.Data_Error;
               end if;
               for Index in 1 .. Count loop
                  State.Unjournaled.Append (Positive'Input (Input'Access));
               end loop;
            end;
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

   function Restore (Directory : String; Model : in out Files.Model.Window_Model) return Boolean is
      Undo, Redo : Files.Model.Undo_Entry_Vectors.Vector;
      State : Files.Model.History_Journal_State;
   begin
      if not Read_Journal (Directory, Undo, Redo, State) then
         return False;
      end if;
      Files.Model.Set_History (Model, Undo, Redo, State);
      return True;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.History_Journal");
         return False;
   end Restore;

   function Merge (Directory : String; Model : in out Files.Model.Window_Model) return Boolean is
      Undo, Redo : Files.Model.Undo_Entry_Vectors.Vector;
      State : Files.Model.History_Journal_State;
   begin
      if not Read_Journal (Directory, Undo, Redo, State) then
         return False;
      end if;
      Files.Model.Merge_History (Model, Undo, Redo, State);
      return True;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.History_Journal");
         return False;
   end Merge;
end Files.History_Journal;
