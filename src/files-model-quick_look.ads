with Guikit.Shared_Bytes;

--  The Quick Look overlay: the item it previews and the content prepared
--  for it.
package Files.Model.Quick_Look is

   --  Open the Quick Look overlay with prepared preview content, capturing the
   --  currently selected item's path as the previewed identity.
   --
   --  @param Model Model to update.
   --  @param Content Prepared preview content the overlay renders.
   procedure Open
     (Model   : in out Window_Model;
      Content : Files.Quick_Look.Quick_Look_Content);

   --  Close the Quick Look overlay and drop its previewed content.
   --
   --  @param Model Model to update.
   procedure Close
     (Model : in out Window_Model);

   --  Give the open preview its decoded image, if it still shows Path.
   --
   --  @param Model Model to update.
   --  @param Path The file the image was decoded from.
   --  @param Pixels Its RGBA pixels.
   --  @param Width Its width.
   --  @param Height Its height.
   procedure Set_Image
     (Model  : in out Window_Model;
      Path   : String;
      Pixels : Guikit.Shared_Bytes.Bytes;
      Width  : Natural;
      Height : Natural);

   --  Toggle the Quick Look overlay. When opening, the previewed content is a
   --  metadata-only info card derived from the selected item without any
   --  filesystem read; when closing, the previewed content is dropped.
   --
   --  @param Model Model to update.
   procedure Toggle
     (Model : in out Window_Model);

   --  Return whether the Quick Look overlay is open.
   --
   --  @param Model Model to inspect.
   --  @return True when Quick Look is active.
   function Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Return the full path of the item Quick Look is previewing.
   --
   --  @param Model Model to inspect.
   --  @return Previewed item full path, or an empty string when closed.
   function Path
     (Model : Window_Model)
      return String;

   --  Return the prepared Quick Look preview content.
   --
   --  @param Model Model to inspect.
   --  @return Preview content; its kind is Info_Content when closed.
   function Content_Of
     (Model : Window_Model)
      return Files.Quick_Look.Quick_Look_Content;

end Files.Model.Quick_Look;
