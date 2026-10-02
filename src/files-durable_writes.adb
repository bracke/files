with Ada.Directories;
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

   function Publish (Temporary, Target : String) return Publication_Result is
      File_Sync : constant Hostkit.Durability.Outcome :=
        Hostkit.Durability.Sync_File (Temporary);
      Replaced : Boolean := False;
   begin
      if File_Sync /= Hostkit.Durability.Synced then
         return Not_Published;
      end if;
      Replaced := Hostkit.Fs.Replace_File (Temporary, Target);
      if not Replaced then
         return Not_Published;
      end if;
      return Outcome_Of
        (File_Sync,
         Replaced       => True,
         Directory_Sync => Hostkit.Durability.Sync_Directory
           (Ada.Directories.Containing_Directory (Target)));
   exception
      when others =>
         return (if Replaced then Published_Not_Durable else Not_Published);
   end Publish;
end Files.Durable_Writes;
