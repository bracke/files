separate (Files.Model)
function Undo_From_Paths
  (Model : Window_Model)
   return Files.Types.String_Vectors.Vector is
begin
   if Model.History.Undo_Stack.Is_Empty then
      return Files.Types.String_Vectors.Empty_Vector;
   end if;

   return Model.History.Undo_Stack.Last_Element.From;
end Undo_From_Paths;
