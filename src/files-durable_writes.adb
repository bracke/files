with Ada.Directories;
with Hostkit.Durability;
with Hostkit.Fs;

package body Files.Durable_Writes is
   use type Hostkit.Durability.Outcome;

   function Publish (Temporary, Target : String) return Boolean is
   begin
      if Hostkit.Durability.Sync_File (Temporary) /= Hostkit.Durability.Synced
        or else not Hostkit.Fs.Replace_File (Temporary, Target)
      then
         return False;
      end if;
      return Hostkit.Durability.Sync_Directory
        (Ada.Directories.Containing_Directory (Target)) /= Hostkit.Durability.Failed;
   exception
      when others => return False;
   end Publish;
end Files.Durable_Writes;
