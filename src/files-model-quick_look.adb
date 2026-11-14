with Files.Model.Support;

package body Files.Model.Quick_Look is

   use Ada.Strings.Unbounded;
   use Files.Model.Support;

   procedure Open
     (Model   : in out Window_Model;
      Content : Files.Quick_Look.Quick_Look_Content) is
   begin
      Touch (Model);
      Claim_Overlay_Input (Model);
      Model.Quick_Look := (Open => True, Path => Selected_Item (Model).Full_Path, Content => Content);
   end Open;

   procedure Close
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Reset_Quick_Look (Model);
   end Close;

   procedure Set_Image
     (Model  : in out Window_Model;
      Path   : String;
      Pixels : Guikit.Shared_Bytes.Bytes;
      Width  : Natural;
      Height : Natural) is
   begin
      if Model.Quick_Look.Open
        and then To_String (Model.Quick_Look.Content.Image_Path) = Path
      then
         Support.Touch_Header (Model);
         Model.Quick_Look.Content.Image_Pixels := Pixels;
         Model.Quick_Look.Content.Image_Width := Width;
         Model.Quick_Look.Content.Image_Height := Height;
      end if;
   end Set_Image;

   procedure Toggle
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      if Model.Quick_Look.Open then
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
            Model.Quick_Look := (Open => True, Path => Item.Full_Path, Content => Content);
         end;
      end if;
   end Toggle;

   function Is_Open
     (Model : Window_Model)
      return Boolean is
     (Model.Quick_Look.Open);

   function Path
     (Model : Window_Model)
      return String is
     (To_String (Model.Quick_Look.Path));

   function Content_Of
     (Model : Window_Model)
      return Files.Quick_Look.Quick_Look_Content is
     (Model.Quick_Look.Content);

end Files.Model.Quick_Look;
