separate (Files.Model)
   procedure Toggle_Quick_Look
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Model.Quick_Look_Active then
         Reset_Quick_Look (Model);
      elsif Selected_Count (Model) = 1 then
         declare
            Item    : constant Files.File_System.Directory_Item := Selected_Item (Model);
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
            Model.Quick_Look_Active        := True;
            Model.Quick_Look_Path_Value    := Item.Full_Path;
            Model.Quick_Look_Content_Value := Content;
         end;
      end if;
   end Toggle_Quick_Look;
