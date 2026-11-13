separate (Files.Model)
procedure Toggle_Quick_Look
  (Model : in out Window_Model) is
begin
   Touch (Model);
   if Model.Quick_Look.Active then
      Reset_Quick_Look (Model);
   elsif Selected_Count (Model) = 1 then
      Claim_Overlay_Input (Model);
      declare
         Item    : constant Files.Items.Directory_Item := Selected_Item (Model);
         Content : constant Files.Quick_Look.Quick_Look_Content :=
           Files.Quick_Look.Prepare_Content
             (Name           => To_String (Item.Name),
              Filetype       => To_String (Item.Filetype),
              Icon_Id        => To_String (Item.Icon_Id),
              Kind           => Item.Kind,
              Size_Available => Item.Size_Available,
              Size           => Item.Size,
              Is_Image       => False,
              Image_Path     => To_String (Item.Full_Path),
              Raw_Bytes      => "");
      begin
         Model.Quick_Look := (Active => True, Path => Item.Full_Path, Content => Content);
      end;
   end if;
end Toggle_Quick_Look;
