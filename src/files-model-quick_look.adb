with Files.Model.Support;

package body Files.Model.Quick_Look is
   use Files.Model.Support;
   use Ada.Strings.Unbounded;

   procedure Open_Quick_Look
     (Model   : in out Window_Model;
      Content : Files.Quick_Look.Quick_Look_Content) is
   begin
      Model.Quick_Look_Active        := True;
      Model.Quick_Look_Path_Value    := Selected_Item (Model).Full_Path;
      Model.Quick_Look_Content_Value := Content;
   end Open_Quick_Look;

   procedure Close_Quick_Look
     (Model : in out Window_Model) is
   begin
      Reset_Quick_Look (Model);
   end Close_Quick_Look;

   procedure Toggle_Quick_Look
     (Model : in out Window_Model) is
   begin
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

   function Quick_Look_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Quick_Look_Active;
   end Quick_Look_Is_Open;

   function Quick_Look_Path
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Quick_Look_Path_Value);
   end Quick_Look_Path;

   function Quick_Look_Content_Of
     (Model : Window_Model)
      return Files.Quick_Look.Quick_Look_Content is
   begin
      return Model.Quick_Look_Content_Value;
   end Quick_Look_Content_Of;

end Files.Model.Quick_Look;
