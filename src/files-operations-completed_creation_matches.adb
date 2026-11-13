separate (Files.Operations)
function Completed_Creation_Matches
  (Action : Files.Model.Undo_Entry; Index : Positive; Path : String)
   return Boolean
is
   Identity : constant String := Files.Model.Created_Identity (Action, Index);
   Expected_Tree_Revision : constant String := Files.Model.Created_Tree_Revision (Action, Index);
begin
   if Identity = "" or else Files.File_Identities.Token (Path) /= Identity then
      return False;
   end if;
   return
     (if Action.Create_Kind = Files.Model.Create_Symbolic_Link
      then Expected_Tree_Revision = ""
      else Expected_Tree_Revision /= ""
        and then Files.File_System.Tree_Revision (Path) = Expected_Tree_Revision);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Operations");
      return False;
end Completed_Creation_Matches;
