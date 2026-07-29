separate (Files.Model)
   function Undo_Kind_Of
     (Model : Window_Model)
      return Undo_Action_Kind is
   begin
      if Model.Undo_Stack.Is_Empty then
         return Undo_None;
      end if;

      return Model.Undo_Stack.Last_Element.Kind;
   end Undo_Kind_Of;
