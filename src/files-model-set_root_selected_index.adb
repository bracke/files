separate (Files.Model)
   procedure Set_Root_Selected_Index
     (Model : in out Window_Model;
      Index : Natural) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if not Model.Root_Selector_Open or else Root_Count (Model) = 0 then
         Model.Root_Selected := 0;
      elsif Index = 0 then
         Model.Root_Selected := 0;
      else
         Model.Root_Selected := Natural'Min (Index, Root_Count (Model));
      end if;
   end Set_Root_Selected_Index;
