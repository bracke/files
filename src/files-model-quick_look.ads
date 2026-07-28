--  The quick look state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Quick_Look is

   --  Open the Quick Look overlay with prepared preview content, capturing the
   --  currently selected item's path as the previewed identity.
   --
   --  @param Model Model to update.
   --  @param Content Prepared preview content the overlay renders.
   procedure Open_Quick_Look
     (Model   : in out Window_Model;
      Content : Files.Quick_Look.Quick_Look_Content);

   --  Close the Quick Look overlay and drop its previewed content.
   --
   --  @param Model Model to update.
   procedure Close_Quick_Look
     (Model : in out Window_Model);

   --  Toggle the Quick Look overlay. When opening, the previewed content is a
   --  metadata-only info card derived from the selected item without any
   --  filesystem read; when closing, the previewed content is dropped.
   --
   --  @param Model Model to update.
   procedure Toggle_Quick_Look
     (Model : in out Window_Model);

   --  Return whether the Quick Look overlay is open.
   --
   --  @param Model Model to inspect.
   --  @return True when Quick Look is active.
   function Quick_Look_Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Return the full path of the item Quick Look is previewing.
   --
   --  @param Model Model to inspect.
   --  @return Previewed item full path, or an empty string when closed.
   function Quick_Look_Path
     (Model : Window_Model)
      return String;

   --  Return the prepared Quick Look preview content.
   --
   --  @param Model Model to inspect.
   --  @return Preview content; its kind is Info_Content when closed.
   function Quick_Look_Content_Of
     (Model : Window_Model)
      return Files.Quick_Look.Quick_Look_Content;

end Files.Model.Quick_Look;
