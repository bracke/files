with Ada.Directories;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with Files.Descriptor_Streams;
with Files.Diagnostics;
with Files.Durability;
with Files.File_Identities;
with Files.Fs_Primitives;
with Files.Io_Errors;
with Files.Private_Directories;
with Hostkit.Fs;
with Hostkit.Regular_Files;

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

   procedure Write_Private_File
     (Temporary : String;
      Write     : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class);
      Identity  : out Files.Types.UString)
   is
      use type GNAT.OS_Lib.File_Descriptor;
      Output : aliased Files.Descriptor_Streams.Output_Stream;
   begin
      Identity := Files.Types.UString'(Ada.Strings.Unbounded.Null_Unbounded_String);
      Output.Descriptor := Hostkit.Regular_Files.Create_New (Temporary, 8#666#);
      if Output.Descriptor = GNAT.OS_Lib.Invalid_FD then
         raise Ada.Directories.Use_Error;
      end if;
      Identity := Ada.Strings.Unbounded.To_Unbounded_String (Files.File_Identities.Token (Temporary));
      if Ada.Strings.Unbounded.Length (Identity) = 0 then
         raise Ada.Directories.Use_Error;
      end if;
      Files.Private_Directories.Make_File_Private (Output.Descriptor);
      Write (Output'Access);
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
      if Files.File_Identities.Token (Temporary) /= Ada.Strings.Unbounded.To_String (Identity) then
         raise Ada.Directories.Use_Error;
      end if;
   exception
      when others =>
         if Output.Descriptor /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Output.Descriptor);
            Output.Descriptor := GNAT.OS_Lib.Invalid_FD;
         end if;
         Remove_Owned (Temporary, Ada.Strings.Unbounded.To_String (Identity));
         Identity := Ada.Strings.Unbounded.Null_Unbounded_String;
         raise;
   end Write_Private_File;

end Files.Durable_Writes;
