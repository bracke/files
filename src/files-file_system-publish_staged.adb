separate (Files.File_System)
function Publish_Staged
  (Staged   : String;
   Target   : String;
   Identity : out UString;
   Revision : out UString)
   return Boolean
is
begin
   Identity := To_Unbounded_String (Files.File_Identities.Token (Staged));
   Revision := To_Unbounded_String (Tree_Revision (Staged));
   if Length (Identity) = 0 or else Length (Revision) = 0 then
      return False;
   end if;
   --  Its tree on the device before it is published, its new name after.
   return Copying.Publish_From_Stage
     (Staged, Target, "", To_String (Identity), Revision, Copying.Flush_Tree_And_Folder);
end Publish_Staged;
