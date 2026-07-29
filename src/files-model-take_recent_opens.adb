separate (Files.Model)
   function Take_Recent_Opens
     (Model : in out Window_Model)
      return Files.Types.String_Vectors.Vector
   is
      Drained : constant Files.Types.String_Vectors.Vector := Model.Recent_Open_Queue;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Recent_Open_Queue.Clear;
      return Drained;
   end Take_Recent_Opens;
