separate (Files.Model)
procedure Open_Quick_Look
  (Model   : in out Window_Model;
   Content : Files.Quick_Look.Quick_Look_Content) is
begin
   Touch (Model);
   Claim_Overlay_Input (Model);
   Model.Quick_Look := (Active => True, Path => Selected_Item (Model).Full_Path, Content => Content);
end Open_Quick_Look;
