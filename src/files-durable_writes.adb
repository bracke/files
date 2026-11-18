with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings.Unbounded;
with Files.Diagnostics;
with Files.Durability;
with Files.Exclusive_Streams;
with Files.File_Identities;
with Files.Fs_Primitives;
with Files.Io_Errors;
with Hostkit.Fs;

package body Files.Durable_Writes is
   use type Hostkit.Durability.Outcome;

   function Outcome_Of
     (File_Sync      : Hostkit.Durability.Outcome;
      Replaced       : Boolean;
      Directory_Sync : Hostkit.Durability.Outcome)
      return Publication_Result
   is
   begin
      if File_Sync /= Hostkit.Durability.Synced or else not Replaced then
         return Not_Published;
      elsif Directory_Sync = Hostkit.Durability.Failed then
         return Published_Not_Durable;
      else
         return Published_Durable;
      end if;
   end Outcome_Of;

   function Publish
     (Temporary, Target : String;
      Step              : out Publication_Step)
      return Publication_Result
   is
      File_Sync : Hostkit.Durability.Outcome;
      Replaced  : Boolean := False;
   begin
      Step := Raised;
      Files.Io_Errors.Clear_Os_Error;
      File_Sync := Files.Durability.Sync_File (Temporary);
      if File_Sync /= Hostkit.Durability.Synced then
         --  A full disk often shows only here, when the data is flushed.
         Files.Io_Errors.Capture;
         Step := File_Sync_Failed;
         return Not_Published;
      end if;
      Files.Io_Errors.Clear_Os_Error;
      Replaced := Hostkit.Fs.Replace_File (Temporary, Target);
      if not Replaced then
         Files.Io_Errors.Capture;
         Step := Replace_Failed;
         return Not_Published;
      end if;
      Step := Completed;
      return Outcome_Of
        (File_Sync,
         Replaced       => True,
         Directory_Sync => Files.Durability.Sync_Directory
           (Files.Fs_Primitives.Parent_Directory (Target)));
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Durable_Writes");
         return (if Replaced then Published_Not_Durable else Not_Published);
   end Publish;

   function Publish (Temporary, Target : String) return Publication_Result is
      Step : Publication_Step;
   begin
      return Publish (Temporary, Target, Step);
   end Publish;
   procedure Remove_Owned (Temporary : String; Identity : String) is
   begin
      if Identity /= "" and then Files.File_Identities.Token (Temporary) = Identity then
         Files.Fs_Primitives.Delete_File (Temporary);
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Durable_Writes");
   end Remove_Owned;

   --  Remove the file at Temporary that this unit just created exclusively,
   --  whose identity could not be read: the creation itself proved it ours.
   procedure Remove_Created (Temporary : String) is
   begin
      if not Hostkit.Fs.Delete_File (Temporary) then
         Files.Diagnostics.Trace ("Files.Durable_Writes", "own_temporary_kept=" & Temporary);
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Durable_Writes");
   end Remove_Created;

   procedure Write_Private_File
     (Temporary : String;
      Write     : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class);
      Identity  : out Files.Types.UString;
      Max_Bytes : Long_Long_Integer := Long_Long_Integer'Last)
   is
      Output  : aliased Files.Exclusive_Streams.Output_Stream;
      Created : Boolean := False;
   begin
      Identity := Files.Types.UString'(Ada.Strings.Unbounded.Null_Unbounded_String);
      Files.Io_Errors.Clear_Os_Error;
      Files.Exclusive_Streams.Create (Output, Temporary);
      Created := True;
      Identity := Ada.Strings.Unbounded.To_Unbounded_String (Files.File_Identities.Token (Temporary));
      if Ada.Strings.Unbounded.Length (Identity) = 0 then
         raise Ada.Directories.Use_Error;
      end if;
      Write (Output'Access);
      if Files.Exclusive_Streams.Size (Output) > Max_Bytes then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Files.Exclusive_Streams.Close (Output);
      if Files.File_Identities.Token (Temporary) /= Ada.Strings.Unbounded.To_String (Identity) then
         raise Ada.Directories.Use_Error;
      end if;
   exception
      when others =>
         Files.Exclusive_Streams.Close_Safely (Output);
         if Created and then Ada.Strings.Unbounded.Length (Identity) = 0 then
            Remove_Created (Temporary);
         elsif Created then
            Remove_Owned (Temporary, Ada.Strings.Unbounded.To_String (Identity));
         end if;
         Identity := Ada.Strings.Unbounded.Null_Unbounded_String;
         raise;
   end Write_Private_File;

   procedure Write_Private_Temporary
     (Base      : String;
      Write     : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class);
      Temporary : out Files.Types.UString;
      Identity  : out Files.Types.UString)
   is
      Max_Candidates : constant := 9_999;
   begin
      Temporary := Ada.Strings.Unbounded.Null_Unbounded_String;
      Identity := Ada.Strings.Unbounded.Null_Unbounded_String;
      for Index in 1 .. Max_Candidates loop
         declare
            Candidate : constant String :=
              Base & ".tmp" & (if Index = 1 then "" else "-" & Files.Types.Natural_Text (Index));
            Taken     : Boolean := False;
         begin
            begin
               Write_Private_File (Candidate, Write, Identity);
               Temporary := Ada.Strings.Unbounded.To_Unbounded_String (Candidate);
               return;
            exception
               when Ada.Directories.Use_Error =>
                  --  Only a name already taken moves on to the next one; a
                  --  refusal of any other kind (a full disk, no right to
                  --  write there) would refuse every name. Asked after the
                  --  failure, as its errno is already recorded.
                  --  refusal-safe: a refused lookup ends the search, failed
                  Taken := Ada.Strings.Unbounded.Length (Identity) = 0
                    and then not Files.Fs_Primitives.Entry_Is_Absent (Candidate);
                  if not Taken then
                     raise;
                  end if;
            end;
         end;
      end loop;
      raise Ada.Directories.Use_Error with "no_free_temporary=" & Base;
   end Write_Private_Temporary;

end Files.Durable_Writes;
