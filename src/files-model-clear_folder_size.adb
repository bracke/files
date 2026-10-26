separate (Files.Model)
procedure Clear_Folder_Size
  (Model : in out Window_Model) is
begin
   --  Released, not driven: a measurement still running is stopped by its
   --  last handle going.
   Model.Folder_Scan := Released_Scan;
   if not Model.Folder_Sizes.Is_Empty then
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Folder_Sizes.Clear;
   end if;
end Clear_Folder_Size;
