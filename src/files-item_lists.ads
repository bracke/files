with Files.Items;
with Files.Types;

--  Directory items built and ordered without touching the disk: the model's
--  placeholders and fallback rows, and the display order it keeps a listing
--  in. Files.File_System, which reads the disk, renames these for its own
--  listings and callers.
package Files.Item_Lists is

   --  Build an item value from its name alone, for placeholders, fallback
   --  rows and tests. Its filetype and icon come from the built-in settings
   --  when not given, and it is hidden when its name starts with a dot: no
   --  host attribute is read.
   --
   --  @param Parent_Path Parent directory path.
   --  @param Name Item name.
   --  @param Kind Filesystem item kind.
   --  @param Filetype Filetype identifier ("" detects it from the name).
   --  @return Directory item value.
   function Make_Item
     (Parent_Path : String;
      Name        : String;
      Kind        : Files.Types.Item_Kind;
      Filetype    : String := "")
      return Files.Items.Directory_Item;

   --  Sort Items in place into the display order for the given sort field and
   --  direction. Shared by directory loading and by the window model so that
   --  keyboard navigation follows exactly the order shown on screen, in either
   --  sort direction.
   --
   --  @param Items Item vector reordered in place.
   --  @param Field Sort field to order by.
   --  @param Ascending Ascending order when True, descending when False.
   procedure Sort_Items
     (Items     : in out Files.Items.Item_Vectors.Vector;
      Field     : Files.Types.Sort_Field;
      Ascending : Boolean);

end Files.Item_Lists;
