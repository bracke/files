separate (Files.Model)
procedure Note_Recent_Open
  (Model : in out Window_Model;
   Path  : String) is
begin
   Touch (Model);
   if Path /= "" then
      Model.Recent_Open_Queue.Append (To_Unbounded_String (Path));
   end if;
end Note_Recent_Open;
