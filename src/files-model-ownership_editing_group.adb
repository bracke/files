separate (Files.Model)
   function Ownership_Editing_Group
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Ownership_Editing_Group_Value;
   end Ownership_Editing_Group;
