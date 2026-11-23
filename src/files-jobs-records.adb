with Ada.Calendar;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings.Unbounded;

with Files.IO.Durable_Writes;
with Files.IO.Fs_Primitives;
with Hostkit.Fs;
with Files.Path_Checks;

package body Files.Jobs.Records is
   use Ada.Strings.Unbounded;

   function Signature_Is_Consistent
     (Value : Files.File_System_Types.Directory_Signature) return Boolean is
   begin
      return Length (Value.Path) = 0
        or else Files.Path_Checks.Valid_Absolute_Path (Value.Path);
   end Signature_Is_Consistent;

   procedure Validate_Size (Size : Long_Long_Integer) is
   begin
      if Size < 0 or else Size > Long_Long_Integer (Max_Transport_Bytes)
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
   end Validate_Size;

   procedure Publish_Result
     (Directory : String;
      Write     : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class);
      Name      : String := Files.Protocol_Names.Result_File)
   is
      Staged   : constant String := Hostkit.Fs.Join (Directory, Files.Protocol_Names.Staged_Name (Name));
      Result   : constant String := Hostkit.Fs.Join (Directory, Name);
      Identity : Files.Types.UString;
   begin
      --  The staged name is fixed and the job's directory is written by its
      --  one owner, so a staged file left behind (its clean-up refused, say
      --  while a scanner held it) is removed before this write rather than
      --  refusing every later publish of the record. Whatever fails below
      --  removes the one this call wrote.
      Files.IO.Durable_Writes.Write_Fixed_Private_File
        (Staged, Write, Identity, Max_Bytes => Long_Long_Integer (Max_Transport_Bytes));
      declare
         Step    : Files.IO.Durable_Writes.Publication_Step;
         Outcome : constant Files.IO.Durable_Writes.Publication_Result :=
           Files.IO.Durable_Writes.Publish (Staged, Result, Step);

         --  refusal-safe: words for a diagnostic, deciding nothing.
         function State (Path : String) return String is
           --  refusal-safe: as above.
           (if Files.IO.Fs_Primitives.Exists (Path) then "present" else "gone");
      begin
         if not Files.IO.Durable_Writes.Published (Outcome) then
            --  Say which part failed, as a machine-readable diagnostic: an
            --  intermittent CI failure here could not be reproduced locally.
            declare
               Message : constant String :=
                 "publish=" & Files.IO.Durable_Writes.Publication_Result'Image (Outcome)
                 & ";step=" & Files.IO.Durable_Writes.Publication_Step'Image (Step)
                 & ";dir=" & State (Directory)
                 & ";tmp=" & State (Staged)
                 & ";result=" & State (Result);
            begin
               Files.IO.Durable_Writes.Remove_Owned (Staged, To_String (Identity));
               raise Ada.Directories.Use_Error with Message;
            end;
         end if;
      end;
   end Publish_Result;

   procedure Write_Signature
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : Files.File_System_Types.Directory_Signature)
   is
   begin
      if not Signature_Is_Consistent (Value) then
         raise Ada.Directories.Use_Error;
      end if;
      Files.IO.Record_Fields.Output_String (Stream, To_String (Value.Path), Max_Path_Length);
      Boolean'Output (Stream, Value.Exists);
      Natural'Output (Stream, Value.Entry_Count);
      Natural'Output (Stream, Value.Entry_State_Checksum);
      Ada.Calendar.Time'Output (Stream, Value.Latest_Modified);
      Boolean'Output (Stream, Value.Latest_Modified_Known);
      Boolean'Output (Stream, Value.Taken);
   end Write_Signature;

   function Read_Signature
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class)
      return Files.File_System_Types.Directory_Signature
   is
      Result : Files.File_System_Types.Directory_Signature;
   begin
      Result.Path := To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Max_Path_Length));
      Result.Exists := Boolean'Input (Stream);
      Result.Entry_Count := Natural'Input (Stream);
      Result.Entry_State_Checksum := Natural'Input (Stream);
      Result.Latest_Modified := Ada.Calendar.Time'Input (Stream);
      Result.Latest_Modified_Known := Boolean'Input (Stream);
      Result.Taken := Boolean'Input (Stream);
      if not Signature_Is_Consistent (Result) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      return Result;
   end Read_Signature;

   --  A move names where it came from, and where it went exactly when it
   --  was not a removal.
   function Path_Move_Is_Consistent (Move : Files.Types.Path_Move) return Boolean is
     (Length (Move.From) > 0
      and then (case Move.Kind is
                   when Files.Types.Moved   => Length (Move.To) > 0,
                   when Files.Types.Removed => Length (Move.To) = 0));

   procedure Write_Path_Moves
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value  : Files.Types.Path_Move_Vectors.Vector)
   is
      Count : constant Natural := Natural'Min (Natural (Value.Length), Max_Path_Moves);
   begin
      Natural'Output (Stream, Count);
      for Index in 1 .. Count loop
         declare
            Move : constant Files.Types.Path_Move := Value (Index);
         begin
            if not Path_Move_Is_Consistent (Move) then
               raise Ada.Directories.Use_Error;
            end if;
            --  The kind goes as its position, which the reader range-checks.
            Natural'Output (Stream, Files.Types.Path_Move_Kind'Pos (Move.Kind));
            Files.IO.Record_Fields.Output_String (Stream, To_String (Move.From), Max_Path_Length);
            Files.IO.Record_Fields.Output_String (Stream, To_String (Move.To), Max_Path_Length);
         end;
      end loop;
   end Write_Path_Moves;

   function Read_Path_Moves
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class)
      return Files.Types.Path_Move_Vectors.Vector
   is
      Count : constant Natural := Natural'Input (Stream);
      Moves : Files.Types.Path_Move_Vectors.Vector;
   begin
      if Count > Max_Path_Moves then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      for Index in 1 .. Count loop
         declare
            Kind_Position : constant Natural := Natural'Input (Stream);
            Move          : Files.Types.Path_Move;
         begin
            if Kind_Position > Files.Types.Path_Move_Kind'Pos (Files.Types.Path_Move_Kind'Last) then
               raise Ada.IO_Exceptions.Data_Error;
            end if;
            Move.Kind := Files.Types.Path_Move_Kind'Val (Kind_Position);
            Move.From := To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Max_Path_Length));
            Move.To := To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Max_Path_Length));
            if not Path_Move_Is_Consistent (Move) then
               raise Ada.IO_Exceptions.Data_Error;
            end if;
            Moves.Append (Move);
         end;
      end loop;
      return Moves;
   end Read_Path_Moves;

end Files.Jobs.Records;
