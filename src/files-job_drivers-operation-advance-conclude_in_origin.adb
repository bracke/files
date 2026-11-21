separate (Files.Job_Drivers.Operation.Advance)
procedure Conclude_In_Origin (Key : String; Kind_Known : Boolean) is
begin
   if Same_View then
      Files.Model.Set_Error (Model, (if Cancelled then "" else Key));
   end if;
   if Kind_Known then
      Note_History_Lost (Work.Kind);
   end if;
   if Same_View then
      Reload_Current_View;
   end if;
end Conclude_In_Origin;
