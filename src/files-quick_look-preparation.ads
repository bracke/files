with Files.Items;

--  Quick Look content for a listed item: the bounded filesystem read the
--  pure Files.Quick_Look.Prepare_Content needs, done here so callers that
--  open or refresh a preview (Files.Operations, Files.Refresh) share
--  one preparation without depending on each other.
package Files.Quick_Look.Preparation is

   --  Prepare Quick Look preview content for a directory item, performing the
   --  bounded filesystem read the pure content-prep seam needs. Image items are
   --  classified with the shared image detector and previewed by path; other
   --  regular files get a capped leading-bytes read for text detection; the rest
   --  fall back to the metadata-only info card. Its Source_Stamp is the item's
   --  (Source_Stamp_Of).
   --
   --  @param Item Directory item to preview.
   --  @return Prepared Quick Look content.
   function Prepare (Item : Files.Items.Directory_Item) return Quick_Look_Content;

end Files.Quick_Look.Preparation;
