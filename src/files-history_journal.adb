with Files.Fs_Primitives;
with Ada.Real_Time;
with Files.Diagnostics;
with Ada.Containers;
with Ada.Streams;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with Files.Bounded_Streams;
with Files.Descriptor_Streams;
with Files.Durable_Writes;
with Files.File_Identities;
with Files.Job_Context;
with Files.Lease_Streams;
with Files.Private_Directories;
with Files.Types;
with Hostkit.Fs;
with Hostkit.Lease_Files;

package body Files.History_Journal is
   use Ada.Strings.Unbounded;
   use type Ada.Containers.Count_Type;
   use type Ada.Directories.File_Kind;
   use type GNAT.OS_Lib.File_Descriptor;
   use type Hostkit.Lease_Files.Open_Outcome;

   Journal_Header : constant String := "files-history-1";
   Max_Journal_Bytes : constant := 64 * 1024 * 1024;
   Max_History_Entries : constant := 200;
   Max_Vector_Fields : constant := 1_000_000;
   Max_Journal_Fields : constant := 2_000_000;
   Max_Field_Length : constant := 32 * 1024;

   function Valid_Directory (Directory : String) return Boolean is
     (Files.Fs_Primitives.Valid_Absolute_Path (Directory, Max_Field_Length));

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
   end Write_Entry;

   function Read_Entry
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Fields : in out Natural)
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
      Fields : in out Natural)
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
         Result.Append (Read_Entry (Stream, Fields));
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
   end Add_Cost;

   --  The stacks less their oldest entries, as many as the journal's caps
   --  need: one very large action (a move of a hundred thousand files) must
   --  not make every later save fail -- and with it every operation's start
   --  and every Undo. The newest entry of each stack (the one in progress)
   --  is kept; the window keeps the whole history in memory, the journal
   --  only what a crash could recover.
   procedure Fit
     (Undo, Redo : in out Files.Model.Undo_Entry_Vectors.Vector;
      Header     : Natural)
   is
      Margin : constant Long_Long_Integer := 1024;
      function Over return Boolean is
         Bytes  : Long_Long_Integer := Long_Long_Integer (Header) + Margin;
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
   begin
      while Over loop
         if Undo.Length > 1 then
            Undo.Delete_First;
         elsif Redo.Length > 1 then
            Redo.Delete_First;
         else
            exit;
         end if;
      end loop;
   end Fit;

   procedure Save_Stacks
     (Directory : String;
      Undo, Redo : Files.Model.Undo_Entry_Vectors.Vector;
      Required : Boolean := False)
   is
      Kept_Undo : Files.Model.Undo_Entry_Vectors.Vector := Undo;
      Kept_Redo : Files.Model.Undo_Entry_Vectors.Vector := Redo;
      Published : Files.Durable_Writes.Publication_Result;
      Total : Natural := Journal_Header'Length + 32;
      Fields : Natural := 0;
      Temporary : constant String := Hostkit.Fs.Join (Directory, "history.tmp");
      Target : constant String := Hostkit.Fs.Join (Directory, "history");
      Output : aliased Files.Descriptor_Streams.Output_Stream;
      Temporary_Identity : Unbounded_String;

      procedure Remove_Owned_Temporary is
      begin
         if Length (Temporary_Identity) > 0
           and then Files.File_Identities.Token (Temporary) =
             To_String (Temporary_Identity)
         then
            Ada.Directories.Delete_File (Temporary);
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.History_Journal");
      end Remove_Owned_Temporary;
   begin
      if Directory = "" then
         return;
      end if;
      if not Valid_Directory (Directory)
        or else Hostkit.Fs.Is_Link (Directory)
        or else not Ada.Directories.Exists (Directory)
        or else Ada.Directories.Kind (Directory) /= Ada.Directories.Directory
        or else Hostkit.Fs.Is_Link (Temporary)
        or else (Ada.Directories.Exists (Temporary)
          and then Ada.Directories.Kind (Temporary) /= Ada.Directories.Ordinary_File)
        or else Hostkit.Fs.Is_Link (Target)
        or else (Ada.Directories.Exists (Target)
          and then Ada.Directories.Kind (Target) /= Ada.Directories.Ordinary_File)
      then
         raise Ada.Directories.Use_Error;
      end if;
      --  A temporary a crash left behind (a plain file, checked above) would
      --  refuse every later save: the journal is ours, so it goes.
      if Ada.Directories.Exists (Temporary) then
         Ada.Directories.Delete_File (Temporary);
      end if;
      Output.Descriptor :=
        GNAT.OS_Lib.Create_New_File (Temporary, GNAT.OS_Lib.Binary);
      if Output.Descriptor = GNAT.OS_Lib.Invalid_FD then
         raise Ada.Directories.Use_Error;
      end if;
      Temporary_Identity := To_Unbounded_String
        (Files.File_Identities.Token (Temporary));
      if Length (Temporary_Identity) = 0 then
         raise Ada.Directories.Use_Error;
      end if;
      Files.Private_Directories.Make_File_Private (Output.Descriptor);
      String'Output (Output'Access, Journal_Header);
      Fit (Kept_Undo, Kept_Redo, Total);
      Write_Stack (Output'Access, Kept_Undo, Total, Fields);
      Write_Stack (Output'Access, Kept_Redo, Total, Fields);
      declare
         Closed : Boolean;
      begin
         Files.Descriptor_Streams.Flush (Output);
         GNAT.OS_Lib.Close (Output.Descriptor, Closed);
         Output.Descriptor := GNAT.OS_Lib.Invalid_FD;
         if not Closed then
            raise Ada.Directories.Use_Error;
         end if;
      end;
      if Files.File_Identities.Token (Temporary) /=
        To_String (Temporary_Identity)
      then
         raise Ada.Directories.Use_Error;
      end if;
      Published := Files.Durable_Writes.Publish
        (Temporary, Target);
      if Files.Durable_Writes.Published (Published) then
         Temporary_Identity := Null_Unbounded_String;
      else
         Remove_Owned_Temporary;
         if Required then
            raise Ada.Directories.Use_Error;
         end if;
      end if;
   exception
      when others =>
         if Output.Descriptor /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Output.Descriptor);
            Output.Descriptor := GNAT.OS_Lib.Invalid_FD;
         end if;
         Remove_Owned_Temporary;
         if Required then
            raise;
         end if;
   end Save_Stacks;

   procedure Save (Model : Files.Model.Window_Model; Required : Boolean := False) is
   begin
      Save_Stacks
        (Files.Job_Context.Directory, Files.Model.Undo_History (Model),
         Files.Model.Redo_History (Model), Required);
   end Save;

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
         Required => True);
      Last_Checkpoint := Ada.Real_Time.Clock;
   end Checkpoint;

   function Restore (Directory : String; Model : in out Files.Model.Window_Model) return Boolean is
      Input : aliased Files.Lease_Streams.Input_Stream;
      Undo, Redo : Files.Model.Undo_Entry_Vectors.Vector;
      Fields : Natural := 0;
      Path : constant String := Hostkit.Fs.Join (Directory, "history");
   begin
      if not Valid_Directory (Directory)
        or else Hostkit.Fs.Is_Link (Directory)
        or else not Ada.Directories.Exists (Directory)
        or else Ada.Directories.Kind (Directory) /= Ada.Directories.Directory
        or else not Ada.Directories.Exists (Path)
        or else Files.Lease_Streams.Open (Path, Input) /=
          Hostkit.Lease_Files.Opened
      then
         return False;
      end if;
      if Files.Lease_Streams.Size (Input) >
        Long_Long_Integer (Max_Journal_Bytes)
        or else Files.Bounded_Streams.Input_String
          (Input'Access, Journal_Header'Length) /= Journal_Header
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Undo := Read_Stack (Input'Access, Fields);
      Redo := Read_Stack (Input'Access, Fields);
      if not Files.Lease_Streams.End_Of_Stream (Input) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Files.Lease_Streams.Release (Input);
      Files.Model.Set_History (Model, Undo, Redo);
      return True;
   exception
      when others =>
         Files.Lease_Streams.Release (Input);
         return False;
   end Restore;
end Files.History_Journal;
