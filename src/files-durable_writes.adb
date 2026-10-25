with Ada.Directories;
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
      File_Sync := Hostkit.Durability.Sync_File (Temporary);
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
         Directory_Sync => Hostkit.Durability.Sync_Directory
           (Ada.Directories.Containing_Directory (Target)));
   exception
      when others =>
         return (if Replaced then Published_Not_Durable else Not_Published);
   end Publish;

   function Publish (Temporary, Target : String) return Publication_Result is
      Step : Publication_Step;
   begin
      return Publish (Temporary, Target, Step);
   end Publish;
end Files.Durable_Writes;
