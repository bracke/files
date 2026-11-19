with Ada.Strings.Unbounded;
with Files.File_System;
with Files.File_System.Thumbnails;

package body Files.Quick_Look.Preparation is
   use Ada.Strings.Unbounded;
   use type Files.Types.Item_Kind;

   function Prepare (Item : Files.Items.Directory_Item) return Quick_Look_Content is
      Name     : constant String := To_String (Item.Name);
      Filetype : constant String := To_String (Item.Filetype);
      Icon_Id  : constant String := To_String (Item.Icon_Id);
      Path     : constant String := To_String (Item.Full_Path);
      Is_Image : constant Boolean :=
        Files.File_System.Thumbnails.Is_Image_Item (Item.Kind, Filetype, Name, Icon_Id);
      Text_File : constant Boolean :=
        not Is_Image
        and then (Item.Kind = Files.Types.Regular_File_Item or else Item.Kind = Files.Types.Executable_Item);
      Read_Ok  : Boolean := False;
      Complete : Boolean := True;
      Raw      : constant String :=
        (if Text_File
         then Files.File_System.Read_Preview_Text (Path, Max_Preview_Bytes, Read_Ok, Complete)
         else "");
      Content : Quick_Look_Content :=
        Prepare_Content
          (Name           => Name,
           Filetype       => Filetype,
           Icon_Id        => Icon_Id,
           Kind           => Item.Kind,
           Size_Available => Item.Size_Available,
           Size           => Item.Size,
           Is_Image       => Is_Image,
           Image_Path     => Path,
           Raw_Bytes      => Raw,
           Bytes_Complete => Complete or else not Read_Ok);
   begin
      --  The original image, so the preview scales the source rather than the
      --  small thumbnail, is decoded off the UI thread: Poll_Quick_Look asks
      --  for it, and the thumbnail shows until it is in.
      Content.Source_Stamp := Source_Stamp_Of (Item);
      return Content;
   end Prepare;

end Files.Quick_Look.Preparation;
