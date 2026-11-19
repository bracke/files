with Ada.Calendar;
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
with Hostkit.Metadata;
with Hostkit.Process;

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
     (Temporary  : String;
      Write      : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class);
      Identity   : out Files.Types.UString;
      Name_Taken : out Boolean;
      Max_Bytes  : Long_Long_Integer := Long_Long_Integer'Last)
   is
      Output  : aliased Files.Exclusive_Streams.Output_Stream;
      Created : Boolean := False;
   begin
      Identity := Files.Types.UString'(Ada.Strings.Unbounded.Null_Unbounded_String);
      Name_Taken := False;
      Files.Io_Errors.Clear_Os_Error;
      begin
         Files.Exclusive_Streams.Create (Output, Temporary);
      exception
         when Ada.IO_Exceptions.Use_Error =>
            --  Asked after the failure, whose errno is already recorded.
            --  refusal-safe: a refused lookup is not a taken name, and the
            --  create's own failure is raised.
            if Files.Fs_Primitives.Entry_Exists (Temporary) then
               Name_Taken := True;
               return;
            end if;
            raise;
      end;
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

   procedure Write_Private_File
     (Temporary : String;
      Write     : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class);
      Identity  : out Files.Types.UString;
      Max_Bytes : Long_Long_Integer := Long_Long_Integer'Last)
   is
      Name_Taken : Boolean;
   begin
      Write_Private_File (Temporary, Write, Identity, Name_Taken, Max_Bytes);
      if Name_Taken then
         --  The create's own failure, recorded with Files.Io_Errors.
         raise Ada.Directories.Use_Error;
      end if;
   end Write_Private_File;

   --  When this process started, near enough: when this unit was elaborated.
   Process_Start : constant Ada.Calendar.Time := Ada.Calendar.Clock;

   --  How much older than Process_Start a temporary must be to be stale.
   Stale_Margin : constant Duration := 60.0;

   procedure Sweep_Stale_Temporaries (Base : String) is
      use type Ada.Calendar.Time;
      use type Hostkit.Metadata.Account_Id;
      Directory : constant String := Files.Fs_Primitives.Parent_Directory (Base);
      Prefix    : constant String := Files.Types.Leaf_Of (Base) & ".tmp";
      User      : Hostkit.Metadata.Account_Id;
      Names     : Files.Types.String_Vectors.Vector;

      --  Base & ".tmp", or Base & ".tmp-" and a number from 2.
      function Temporary_Name (Name : String) return Boolean is
        (Name = Prefix
         or else (Name'Length in Prefix'Length + 2 .. Prefix'Length + 5
                  and then Name (Name'First .. Name'First + Prefix'Length - 1) = Prefix
                  and then Name (Name'First + Prefix'Length) = '-'
                  and then Name (Name'First + Prefix'Length + 1) in '1' .. '9'
                  and then (for all C of Name (Name'First + Prefix'Length + 2 .. Name'Last) => C in '0' .. '9')));

      procedure Collect (Name : String; Stop : in out Boolean) is
      begin
         if Temporary_Name (Name) then
            Names.Append (Ada.Strings.Unbounded.To_Unbounded_String (Name));
         end if;
         Stop := Natural (Names.Length) >= 10_000;
      end Collect;

      procedure Remove_If_Stale (Path : String) is
         Identity : constant String := Files.File_Identities.Token (Path);
         Status   : constant Hostkit.Metadata.Entry_Status := Hostkit.Metadata.Entry_Status_Of (Path);
      begin
         if Identity /= ""
           and then not Hostkit.Fs.Is_Link (Path)
           and then Files.Fs_Primitives.File_Exists (Path)
           and then Status.Available
           and then Status.User_Id = User
           and then Status.Mode mod 8#100# = 0
           and then Hostkit.Fs.Modification_Time_Of (Path, Follow_Links => False) < Process_Start - Stale_Margin
         then
            Remove_Owned (Path, Identity);
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Durable_Writes");
      end Remove_If_Stale;
   begin
      if Directory = ""
        or else not Hostkit.Metadata.Mode_Bits_Are_Native
        or else not Hostkit.Process.Current_User_Account (User)
      then
         return;
      end if;
      Files.Fs_Primitives.For_Each_Name (Directory, Collect'Access);
      for Name of Names loop
         Remove_If_Stale (Hostkit.Fs.Join (Directory, Ada.Strings.Unbounded.To_String (Name)));
      end loop;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Durable_Writes");
   end Sweep_Stale_Temporaries;

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
            Taken     : Boolean;
         begin
            --  Only a name already taken moves on to the next one; a refusal
            --  of any other kind (a full disk, no right to write there, a
            --  failure after the create) would refuse every name, and is
            --  raised. refusal-safe: a refused lookup is not a taken name
            --  (Write_Private_File), so it ends the search.
            Write_Private_File (Candidate, Write, Identity, Taken);
            if not Taken then
               Temporary := Ada.Strings.Unbounded.To_Unbounded_String (Candidate);
               return;
            end if;
         end;
      end loop;
      raise Ada.Directories.Use_Error with "no_free_temporary=" & Base;
   end Write_Private_Temporary;

   function Write_And_Publish
     (Target : String;
      Write  : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class))
      return Publication_Result
   is
      use Ada.Strings.Unbounded;
      Temporary, Identity : Files.Types.UString;
      Result : Publication_Result;
   begin
      --  refusal-safe: a Target that cannot be looked at is neither absent
      --  nor a plain file, so it refuses the write.
      if Hostkit.Fs.Is_Link (Target)
        or else (not Files.Fs_Primitives.Entry_Is_Absent (Target)
          and then not Files.Fs_Primitives.File_Exists (Target))
      then
         raise Ada.Directories.Use_Error;
      end if;
      Write_Private_Temporary (Target, Write, Temporary, Identity);
      Result := Publish (To_String (Temporary), Target);
      if not Published (Result) then
         Remove_Owned (To_String (Temporary), To_String (Identity));
      end if;
      return Result;
   exception
      when others =>
         if Length (Temporary) > 0 then
            Remove_Owned (To_String (Temporary), To_String (Identity));
         end if;
         raise;
   end Write_And_Publish;

end Files.Durable_Writes;
