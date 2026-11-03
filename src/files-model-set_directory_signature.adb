separate (Files.Model)
procedure Set_Directory_Signature
  (Model     : in out Window_Model;
   Signature : Files.File_System.Directory_Signature)
is
   use type Files.File_System.Directory_Signature;
begin
   --  The watch poll stores what it found every time; only a change is news,
   --  and a revision forces a full snapshot rebuild.
   if Model.Directory_Signature /= Signature then
      Touch (Model);
      Model.Directory_Signature := Signature;
   end if;
end Set_Directory_Signature;
