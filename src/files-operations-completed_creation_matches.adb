separate (Files.Operations)
function Completed_Creation_Matches
  (Action : Files.Undo.History.Undo_Entry; Index : Positive; Path : String)
   return Boolean
is
   Identity : constant String := To_String (Action.Items (Index).Identity);
   Expected_Tree_Revision : constant String := To_String (Action.Items (Index).Tree_Revision);
begin
   if Identity = "" or else Files.File_Identities.Token (Path) /= Identity then
      return False;
   end if;
   return
     (if Action.Create_Kind = Files.Undo.History.Create_Symbolic_Link
      then Expected_Tree_Revision = ""
      else Expected_Tree_Revision /= ""
        and then Files.File_System.Tree_Revision (Path) = Expected_Tree_Revision);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Operations");
      return False;
end Completed_Creation_Matches;
