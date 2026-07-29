separate (Files.Model)
   procedure Note_Recent_Open
     (Model : in out Window_Model;
      Path  : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Path /= "" then
         Model.Recent_Open_Queue.Append (To_Unbounded_String (Path));
      end if;
   end Note_Recent_Open;
