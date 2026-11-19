with Files.Durability;
with Hostkit.Durability;
separate (Files.File_System)
function Publish_Staged
  (Staged   : String;
   Target   : String;
   Identity : out UString;
   Revision : out UString)
   return Boolean
is
   use type Hostkit.Durability.Outcome;
begin
   Identity := To_Unbounded_String (Files.File_Identities.Token (Staged));
   Revision := To_Unbounded_String (Tree_Revision (Staged));
   if Length (Identity) = 0 or else Length (Revision) = 0
     or else Files.Durability.Sync_Tree (Staged) = Hostkit.Durability.Failed
   then
      return False;
   end if;
   --  Named before it is published, so a helper stopped right after still
   --  has it found for Undo (Files.Job_Context.Read_Created).
   Files.Job_Context.Intend_Created (Target, "", To_String (Identity), To_String (Revision));
   if not Hostkit.Fs.Move_No_Replace (Staged, Target) then
      return False;
   end if;
   --  The access the destination hands down, as for a copy published there.
   Support.Inherit_Destination_Access (Target, Revision);
   Files.Job_Context.Record_Created (Target, "", To_String (Identity), To_String (Revision));
   --  The new name on the device. The entry is published and recorded
   --  whatever this answers, as Durable_Writes.Publish's callers take a
   --  Published_Not_Durable write: its contents are on the device, only the
   --  name may be lost to a crash. The failure is traced.
   if Files.Durability.Sync_Directory (Parent_Directory (Target)) = Hostkit.Durability.Failed then
      Files.Diagnostics.Trace ("Files.File_System", "published_not_durable=" & Target);
   end if;
   return True;
end Publish_Staged;
